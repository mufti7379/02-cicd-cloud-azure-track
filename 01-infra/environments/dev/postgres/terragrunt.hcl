# Component: postgres (PostgreSQL Flexible Server, Private Access, Entra ID Auth)
# Ketergantungan: network (subnet delegated + Private DNS), aks (OIDC issuer Workload Identity)
#
# ⚠️ Password standard user TIDAK disimpan di file ini (repo invariant: tanpa secret plaintext).
# Sebelum plan/apply:  export TF_VAR_standard_db_password='<min 8 char: huruf besar+kecil+angka/simbol>'

include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "${get_terragrunt_dir()}/../../../modules/postgres"
}

locals {
  env = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

# --- Dependencies ---
# Server butuh subnet delegated + Private DNS zone dari network agar dapat IP privat.
dependency "network" {
  config_path = "../network"

  mock_outputs = {
    postgres_subnet_id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock/providers/Microsoft.Network/virtualNetworks/mock/subnets/mock"
    postgres_private_dns_zone_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock/providers/Microsoft.Network/privateDnsZones/mock.postgres.database.azure.com"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "aks" {
  config_path = "../aks"

  mock_outputs = {
    oidc_issuer_url = "https://mock.oic.prod-aks.azure.com/00000000-0000-0000-0000-000000000000/mock/"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  instance_name = "course-pg-dev" # ← GANTI jika bentrok: unik global (bagian FQDN)

  # Inject subnet & DNS zone dari output modul network
  delegated_subnet_id = dependency.network.outputs.postgres_subnet_id
  private_dns_zone_id = dependency.network.outputs.postgres_private_dns_zone_id

  # Konfigurasi Workload Identity
  iam_identity_name        = "backend-go-db"
  oidc_issuer_url          = dependency.aks.outputs.oidc_issuer_url
  k8s_namespace            = "backend-development"
  k8s_service_account_name = "backend-go"

  # Standard user untuk backend-go-cinema (password dari TF_VAR_standard_db_password)
  standard_db_user = "cinema-dev-user"

  tags = {
    managed_by  = "terraform"
    course      = "be-a-devops-employee"
    environment = "dev"
    component   = "postgres"
  }
}
