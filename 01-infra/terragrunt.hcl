# =============================================================================
# Root Terragrunt config untuk stage 01-infra.
# Menghasilkan backend.tf + provider.tf untuk setiap unit (component),
# sehingga setiap component punya state TERPISAH.
#
# Manfaat:
# - Ubah 1 component (mis. compute) → plan/apply hanya menyentuh state-nya saja (cepat).
# - Tidak ada lagi "comment module = destroy"; tiap component punya lifecycle sendiri.
# - `terragrunt run-all apply` dari environments/<env>/ tetap bisa apply semua sekaligus
#   dengan urutan otomatis dari blok `dependency`.
#
# Autentikasi (padanan impersonation GCP):
# - Dari laptop: `az login` (backend & provider memakai Azure CLI).
# - Dari Jenkins/CI: export ARM_USE_MSI=true dan ARM_CLIENT_ID=<terraform_identity_client_id>
#   (output stage 00) — dibaca otomatis oleh backend & provider azurerm.
# =============================================================================

locals {
  env = read_terragrunt_config(find_in_parent_folders("env.hcl"))

  subscription_id       = local.env.locals.subscription_id
  location              = local.env.locals.location
  resource_group_name   = local.env.locals.resource_group_name
  state_resource_group  = local.env.locals.state_resource_group
  state_storage_account = local.env.locals.state_storage_account
  state_container       = local.env.locals.state_container
}

# State remote per-component (key unik dari path relatif unit).
remote_state {
  backend = "azurerm"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    subscription_id      = local.subscription_id
    resource_group_name  = local.state_resource_group
    storage_account_name = local.state_storage_account
    container_name       = local.state_container
    key                  = "01-infra/${path_relative_to_include()}/terraform.tfstate"
    use_azuread_auth     = true
  }
}

# Provider di-generate seragam untuk semua component.
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "azurerm" {
  subscription_id = "${local.subscription_id}"

  # Resource provider sudah didaftarkan di stage 00-bootstrap.
  resource_provider_registrations = "none"

  features {}
}
EOF
}

# Input umum yang diteruskan ke semua module.
inputs = {
  location            = local.location
  resource_group_name = local.resource_group_name
}
