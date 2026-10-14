# Module: keyvault
# Membuat Key Vault, Key, dan Managed Identity untuk Vault Auto-Unseal (padanan Cloud KMS).
# Menghubungkan identity Azure ke KSA Vault via Workload Identity (federated credential).

data "azurerm_client_config" "current" {}

# 1. Key Vault (padanan Key Ring) — otorisasi data-plane via Azure RBAC
resource "azurerm_key_vault" "vault" {
  name                       = var.key_vault_name
  resource_group_name        = var.resource_group_name
  location                   = var.location
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard" # key software-protected (padanan KMS protection level SOFTWARE)
  rbac_authorization_enabled = true
  soft_delete_retention_days = 7

  # true = key tidak bisa di-purge sebelum masa retensi habis (production).
  # Lab: false agar nama vault bisa dipakai ulang setelah teardown + purge.
  purge_protection_enabled = var.purge_protection_enabled

  tags = var.tags
}

# Pemanggil Terraform butuh hak data-plane untuk membuat key (Owner tidak mencakup data action).
resource "azurerm_role_assignment" "deployer_crypto_officer" {
  scope                = azurerm_key_vault.vault.id
  role_definition_name = "Key Vault Crypto Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Propagasi role assignment butuh waktu — tunggu sebelum membuat key agar tidak 403.
resource "time_sleep" "rbac_propagation" {
  create_duration = "60s"

  depends_on = [azurerm_role_assignment.deployer_crypto_officer]
}

# 2. Key (padanan Crypto Key) — Vault seal azurekeyvault memakai wrap/unwrap
resource "azurerm_key_vault_key" "vault" {
  name         = var.crypto_key_name
  key_vault_id = azurerm_key_vault.vault.id
  key_type     = "RSA"
  key_size     = 2048
  key_opts     = ["wrapKey", "unwrapKey"]

  lifecycle {
    prevent_destroy = true # Proteksi data agar key tidak terhapus
  }

  depends_on = [time_sleep.rbac_propagation]
}

# 3. Managed Identity untuk Vault (padanan SA vault-sa)
resource "azurerm_user_assigned_identity" "vault" {
  name                = var.identity_name
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

# 4. RBAC di level key: izinkan identity Vault wrap/unwrap dengan key ini
resource "azurerm_role_assignment" "vault" {
  scope                = azurerm_key_vault_key.vault.resource_versionless_id
  role_definition_name = "Key Vault Crypto User" # padanan roles/cloudkms.cryptoKeyEncrypterDecrypter
  principal_id         = azurerm_user_assigned_identity.vault.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "vault_viewer" {
  scope                = azurerm_key_vault_key.vault.resource_versionless_id
  role_definition_name = "Key Vault Reader" # padanan roles/cloudkms.viewer
  principal_id         = azurerm_user_assigned_identity.vault.principal_id
  principal_type       = "ServicePrincipal"
}

# 5. Workload Identity: izinkan K8s SA 'vault' memakai identity ini
# (padanan roles/iam.workloadIdentityUser). KSA perlu annotation
# azure.workload.identity/client-id = output identity_client_id.
resource "azurerm_federated_identity_credential" "vault" {
  name                = "${var.vault_namespace}-${var.vault_service_account_name}"
  resource_group_name = var.resource_group_name
  parent_id           = azurerm_user_assigned_identity.vault.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = var.oidc_issuer_url
  subject             = "system:serviceaccount:${var.vault_namespace}:${var.vault_service_account_name}"
}
