# =============================================================================
# Stage 00 — Bootstrap (Azure)
# Membuat fondasi subscription: resource group, storage account untuk Terraform
# state, dan managed identity yang dipakai Terraform/CI pada stage berikutnya.
# Resource provider (padanan "enable API" GCP) didaftarkan di provider.tf.
# Berjalan dengan LOCAL state (lihat catatan di versions.tf).
# =============================================================================

data "azurerm_client_config" "current" {}

data "azurerm_subscription" "current" {}

# 1) Resource group untuk resource fondasi.
# Di GCP project sudah jadi wadah; di Azure setiap resource wajib berada di resource group.
resource "azurerm_resource_group" "bootstrap" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# 2) Storage account + container untuk Terraform remote state stage berikutnya.
resource "azurerm_storage_account" "tf_state" {
  name                     = var.state_storage_account_name
  resource_group_name      = azurerm_resource_group.bootstrap.name
  location                 = azurerm_resource_group.bootstrap.location
  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = "LRS"

  # Best practice keamanan & keselamatan state:
  https_traffic_only_enabled      = true
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false # padanan public_access_prevention = "enforced"
  default_to_oauth_authentication = true  # portal/CLI default ke Entra ID, bukan access key

  blob_properties {
    versioning_enabled = true

    # Soft delete — state yang terhapus tidak sengaja masih bisa di-restore.
    delete_retention_policy {
      days = 7
    }
    container_delete_retention_policy {
      days = 7
    }
  }

  tags = var.tags

  # ⚠️ PROTEKSI DESTROY (AD-18): State storage kritis — kehilangan = kehilangan seluruh state.
  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_storage_container" "tf_state" {
  name                  = var.state_container_name
  storage_account_id    = azurerm_storage_account.tf_state.id
  container_access_type = "private"

  lifecycle {
    prevent_destroy = true
  }
}

# 3) Managed identity untuk Terraform (tanpa secret/key file) — padanan SA Terraform.
# Azure tidak punya "impersonation" untuk user: dari laptop Terraform berjalan sebagai
# user `az login`; identity ini di-attach ke VM Jenkins / dipakai CI via federated
# credential (OIDC) pada stage berikutnya.
resource "azurerm_user_assigned_identity" "terraform" {
  name                = var.terraform_identity_name
  resource_group_name = azurerm_resource_group.bootstrap.name
  location            = azurerm_resource_group.bootstrap.location
  tags                = var.tags
}

# 4) Role untuk identity Terraform agar bisa provisioning stage berikutnya.
resource "azurerm_role_assignment" "terraform_identity_roles" {
  for_each = toset(var.terraform_identity_roles)

  scope                = data.azurerm_subscription.current.id
  role_definition_name = each.value
  principal_id         = azurerm_user_assigned_identity.terraform.principal_id
  principal_type       = "ServicePrincipal"
}

# Izin assign role ke identity lain (padanan roles/resourcemanager.projectIamAdmin),
# DIBATASI ABAC condition hanya ke role di var.terraform_assignable_roles.
# Anti self-bypass: identity tidak bisa memberi dirinya Owner / User Access Administrator /
# Resource Policy Contributor untuk menghapus policy di langkah 6.
data "azurerm_role_definition" "assignable" {
  for_each = toset(var.terraform_assignable_roles)

  name  = each.value
  scope = data.azurerm_subscription.current.id
}

locals {
  assignable_role_guids = join(", ", sort([for r in data.azurerm_role_definition.assignable : r.role_definition_id]))
}

resource "azurerm_role_assignment" "terraform_rbac_admin" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Role Based Access Control Administrator"
  principal_id         = azurerm_user_assigned_identity.terraform.principal_id
  principal_type       = "ServicePrincipal"

  condition_version = "2.0"
  condition         = <<-EOT
    (
      (
        !(ActionMatches{'Microsoft.Authorization/roleAssignments/write'})
      )
      OR
      (
        @Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {${local.assignable_role_guids}}
      )
    )
    AND
    (
      (
        !(ActionMatches{'Microsoft.Authorization/roleAssignments/delete'})
      )
      OR
      (
        @Resource[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {${local.assignable_role_guids}}
      )
    )
  EOT
}

# 5) Akses data plane ke state (Storage Blob Data Contributor) agar backend stage
# berikutnya bisa memakai `use_azuread_auth = true` — tanpa access key.
# Padanan impersonation GCP: identity Terraform + user yang menjalankan bootstrap
# + var.state_data_contributors.
resource "azurerm_role_assignment" "terraform_state_data" {
  scope                = azurerm_storage_account.tf_state.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.terraform.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "state_data_contributors" {
  for_each = toset(concat([data.azurerm_client_config.current.object_id], var.state_data_contributors))

  scope                = azurerm_storage_account.tf_state.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = each.value
}

# =============================================================================
# 6) Azure Policy denyAction — blokir DELETE resource stateful (AD-18).
# Padanan IAM Deny Policy GCP. Perbedaan: berlaku untuk SEMUA principal (bukan hanya
# identity Terraform) — teardown yang disengaja wajib mematikan toggle dulu.
# Toggle: var.enable_terraform_destroy_deny (default true).
# Anti self-bypass: identity Terraform (Contributor + RBAC Admin terbatas) tidak punya
# Microsoft.Authorization/policyAssignments/delete → tidak bisa menghapus policy ini.
# Keterbatasan: mode Indexed tidak mengevaluasi subnet; efek butuh hingga ~30 menit
# setelah assignment dibuat/dihapus.
# =============================================================================
resource "azurerm_policy_definition" "deny_delete_stateful" {
  count = var.enable_terraform_destroy_deny ? 1 : 0

  name         = "deny-delete-stateful"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "Deny delete of stateful resources"

  policy_rule = jsonencode({
    if = {
      field = "type"
      in    = var.protected_resource_types
    }
    then = {
      effect = "denyAction"
      details = {
        actionNames = ["delete"]
        # Blokir juga delete resource group yang berisi resource terlindungi.
        cascadeBehaviors = {
          resourceGroup = "deny"
        }
      }
    }
  })
}

resource "azurerm_subscription_policy_assignment" "deny_delete_stateful" {
  count = var.enable_terraform_destroy_deny ? 1 : 0

  name                 = "deny-delete-stateful"
  display_name         = "Deny delete of stateful resources"
  subscription_id      = data.azurerm_subscription.current.id
  policy_definition_id = azurerm_policy_definition.deny_delete_stateful[0].id
}
