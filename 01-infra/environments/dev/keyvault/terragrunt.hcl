# Component: keyvault
# Azure Key Vault + Key + Managed Identity untuk Vault Auto-Unseal (padanan Cloud KMS).
# Dependency ke aks (OIDC issuer) untuk federated credential Workload Identity.

include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "${get_terragrunt_dir()}/../../../modules/keyvault"
}

locals {
  env = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

dependencies {
  paths = ["../resource-group"]
}

dependency "aks" {
  config_path = "../aks"

  mock_outputs = {
    oidc_issuer_url = "https://mock.oic.prod-aks.azure.com/00000000-0000-0000-0000-000000000000/mock/"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  key_vault_name  = "kv-vault-unseal-dev" # ← GANTI jika bentrok: unik global, maks 24 karakter
  crypto_key_name = "vault-unseal-key"
  identity_name   = "id-vault"

  oidc_issuer_url            = dependency.aks.outputs.oidc_issuer_url
  vault_namespace            = "vault"
  vault_service_account_name = "vault"

  # Lab: false agar teardown bersih. Production: true (tidak bisa dimatikan lagi).
  purge_protection_enabled = false

  tags = {
    managed_by  = "terraform"
    course      = "be-a-devops-employee"
    environment = "dev"
    component   = "vault-kms"
  }
}
