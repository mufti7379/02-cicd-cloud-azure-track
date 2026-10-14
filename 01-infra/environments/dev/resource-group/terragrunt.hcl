# Component: resource-group (wadah semua resource stage 01 untuk env ini)
# Nama & region diambil dari env.hcl via inputs root. Unit lain bergantung pada unit ini.

include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "${get_terragrunt_dir()}/../../../modules/resource-group"
}

inputs = {
  # --- Tags ---
  tags = {
    managed_by  = "terraform"
    course      = "be-a-devops-employee"
    environment = "dev"
  }
}
