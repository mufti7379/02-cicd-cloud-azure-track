# Konfigurasi per-environment (dev). Edit nilai di bawah sesuai subscription-mu.
# Ini analog dengan terraform.tfvars, tapi untuk Terragrunt.
# Tidak memuat secret → aman di-commit. Untuk nilai rahasia, gunakan TF_VAR_* / env.
locals {
  subscription_id = "00000000-0000-0000-0000-000000000000" # GANTI: az account show --query id -o tsv
  location        = "southeastasia"
  zone            = "1" # availability zone di dalam region (1/2/3)

  # Resource group untuk semua resource stage 01 di environment ini.
  resource_group_name = "rg-course-dev"

  # Output dari stage 00-bootstrap:
  state_resource_group  = "rg-bootstrap"
  state_storage_account = "GANTI-state_storage_account_name"
  state_container       = "tfstate"
}
