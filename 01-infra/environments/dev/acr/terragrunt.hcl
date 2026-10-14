# Component: acr
# Azure Container Registry untuk menyimpan Docker images CI/CD pipeline.
# State terpisah; dependency ke aks (kubelet identity) & compute (identity Jenkins)
# untuk role AcrPull/AcrPush — tidak perlu copy-paste identity manual.
#
# PESERTA: edit nilai di inputs{} sesuai kebutuhan.
# Jangan ubah modules/acr/*.tf langsung.

include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "${get_terragrunt_dir()}/../../../modules/acr"
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
    kubelet_identity_object_id = "00000000-0000-0000-0000-000000000000"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "compute" {
  config_path = "../compute"

  mock_outputs = {
    vm_identity_principal_id = "00000000-0000-0000-0000-000000000000"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  # --- Registry config ---
  registry_name = "acrcoursedev"         # ← GANTI: unik global, huruf/angka saja (mis. acrcoursedev<inisial>)
  sku           = "Basic"                # termurah; cukup untuk lab
  repository_id = "docker-images-course" # namespace image (match dengan pipeline.yaml registry.repository)

  # --- Cleanup policy: hemat storage ---
  # ACR Tasks tidak tersedia di subscription free trial/credit → set false jika apply gagal.
  enable_cleanup_policy   = true
  keep_count              = 2 # pertahankan 2 tag terbaru per repo
  untagged_retention_days = 7 # hapus image lama (di luar keep_count) & untagged setelah 7 hari

  # --- IAM ---
  aks_kubelet_principal_id = dependency.aks.outputs.kubelet_identity_object_id   # AcrPull
  jenkins_principal_id     = dependency.compute.outputs.vm_identity_principal_id # AcrPush

  # --- Tags ---
  tags = {
    managed_by  = "terraform"
    course      = "be-a-devops-employee"
    environment = "dev"
    component   = "acr"
  }
}
