# =============================================================================
# Module: postgres
# Azure Database for PostgreSQL Flexible Server (padanan Cloud SQL) dengan
# private access (VNet integration), SSL wajib, dan autentikasi Entra ID + Workload Identity.
# =============================================================================

data "azurerm_client_config" "current" {}

resource "azurerm_postgresql_flexible_server" "main" {
  name                  = var.instance_name
  resource_group_name   = var.resource_group_name
  location              = var.location
  version               = var.database_version
  sku_name              = var.sku_name # Contoh: B_Standard_B1ms untuk hemat biaya
  storage_mb            = var.storage_mb
  backup_retention_days = 7

  # Private access: subnet delegated + private DNS dari module network (padanan Private IP + PSA).
  # SSL wajib secara default (server parameter require_secure_transport = on).
  delegated_subnet_id           = var.delegated_subnet_id
  private_dns_zone_id           = var.private_dns_zone_id
  public_network_access_enabled = false

  # Login password (standard user) + Entra ID (padanan flag cloudsql.iam_authentication).
  administrator_login    = var.standard_db_user
  administrator_password = var.standard_db_password

  authentication {
    active_directory_auth_enabled = true
    password_auth_enabled         = true
    tenant_id                     = data.azurerm_client_config.current.tenant_id
  }

  tags = var.tags

  lifecycle {
    # Azure memilih availability zone saat create; abaikan agar tidak terjadi drift.
    ignore_changes = [zone]
  }
}

# Membuat database default
resource "azurerm_postgresql_flexible_server_database" "default" {
  name      = var.db_name
  server_id = azurerm_postgresql_flexible_server.main.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

# --- Managed Identity untuk akses DB (padanan GCP SA + Workload Identity) ---
resource "azurerm_user_assigned_identity" "db" {
  name                = var.iam_identity_name
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

# Binding identity ke KSA via Workload Identity (padanan roles/iam.workloadIdentityUser).
# KSA perlu annotation azure.workload.identity/client-id = output iam_identity_client_id.
resource "azurerm_federated_identity_credential" "db" {
  name                = "${var.k8s_namespace}-${var.k8s_service_account_name}"
  resource_group_name = var.resource_group_name
  parent_id           = azurerm_user_assigned_identity.db.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = var.oidc_issuer_url
  subject             = "system:serviceaccount:${var.k8s_namespace}:${var.k8s_service_account_name}"
}

# User database berbasis identity (padanan google_sql_user CLOUD_IAM_SERVICE_ACCOUNT).
# Nama user PostgreSQL = nama identity; password = access token Entra ID.
# Catatan: di Flexible Server, principal Entra non-admin hanya bisa dibuat via SQL
# (pgaadauth_create_principal), jadi identity ini dijadikan Entra admin — setara hak
# standard user Cloud SQL (anggota cloudsqlsuperuser). Untuk production least-privilege:
# jadikan admin manusia sebagai Entra admin lalu buat principal aplikasi via SQL.
resource "azurerm_postgresql_flexible_server_active_directory_administrator" "db_identity" {
  server_name         = azurerm_postgresql_flexible_server.main.name
  resource_group_name = var.resource_group_name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  object_id           = azurerm_user_assigned_identity.db.principal_id
  principal_name      = azurerm_user_assigned_identity.db.name
  principal_type      = "ServicePrincipal"
}
