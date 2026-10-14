# Component: compute (VM Jenkins + dedicated managed identity + reserved IP, SSH dibatasi NSG)
# Bergantung pada output component network.
#
# SEMUA variabel configurable di-pass eksplisit di sini (AD-2: parameterisasi penuh).
# Peserta cukup edit file INI saja — tidak perlu ubah modules/compute/variables.tf.
#
# ⚠️ SETTINGAN YANG TIDAK BISA DIUBAH SETELAH APPLY (force recreate VM):
#   - zone, image, disk_type, preemptible, subnet, admin_username, SSH key
#   Pastikan benar SEBELUM pertama kali apply!

include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "${get_terragrunt_dir()}/../../../modules/compute"
}

locals {
  env = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

dependency "network" {
  config_path = "../network"

  mock_outputs = {
    subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock/providers/Microsoft.Network/virtualNetworks/mock/subnets/mock"
    application_security_group_ids = {
      ssh     = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock/providers/Microsoft.Network/applicationSecurityGroups/asg-ssh"
      webhook = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock/providers/Microsoft.Network/applicationSecurityGroups/asg-webhook"
    }
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  # --- Zone (⚠️ force recreate jika diubah) ---
  zone = local.env.locals.zone

  # --- Instance config ---
  instance_name = "vm-jenkins-dev"
  vm_size       = "Standard_D2as_v5" # 2 vCPU / 8 GB. Bisa diubah setelah apply (VM restart).
  image = {                          # ⚠️ force recreate
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }
  disk_size_gb = 30             # minimal 30 (ukuran image Ubuntu); bisa diperbesar, tidak bisa dikecilkan
  disk_type    = "Standard_LRS" # HDD — paling murah. ⚠️ force recreate

  # --- Spot VM (⚠️ force recreate jika diubah!) ---
  # Jauh lebih murah, tapi VM bisa di-evict kapan saja (VM di-deallocate, disk tetap).
  # Build Jenkins yang sedang jalan bisa terputus. Acceptable untuk lab.
  # Set false untuk production yang butuh uptime stabil.
  # Catatan: seri B (mis. Standard_B2s) TIDAK mendukung Spot.
  preemptible = true

  # --- Networking (dari dependency network) ---
  subnet_id = dependency.network.outputs.subnet_id

  # --- IP publik reserved (stabil untuk DNS, webhook, TLS cert) ---
  # IP akan di-reserve secara otomatis dan tidak berubah meskipun VM di-stop/start.
  # Pakai IP ini untuk set DNS A record: jenkins.yourdomain.com → IP ini
  enable_public_ip = true

  # --- Dedicated managed identity (least privilege, scope resource group) ---
  vm_identity_name = "id-vm-jenkins"
  vm_identity_roles = [
    "Monitoring Metrics Publisher", # kirim metrics ke Azure Monitor
    "AcrPull",                      # pull image dari ACR (Kaniko)
  ]

  # --- ASG (padanan network tags; harus match NSG rule di module network) ---
  application_security_group_ids = [
    for name in ["ssh", "webhook"] : dependency.network.outputs.application_security_group_ids[name]
  ]

  # --- Login ---
  # SSH key admin dibaca dari file lokal. Override path: export SSH_PUBLIC_KEY_PATH=~/.ssh/id_rsa.pub
  admin_username       = "azureuser"
  admin_ssh_public_key = file(pathexpand(get_env("SSH_PUBLIC_KEY_PATH", "~/.ssh/id_ed25519.pub")))

  # enable_entra_ssh_login: TRUE = login via Entra ID (`az ssh vm`, audit trail, tanpa manage SSH key)
  #                         FALSE = SSH key biasa (lebih simple)
  enable_entra_ssh_login = false # ← set true jika sudah grant role "Virtual Machine Administrator Login"

  # --- Tags ---
  tags = {
    managed_by  = "terraform"
    course      = "be-a-devops-employee"
    environment = "dev"
    role        = "jenkins"
  }

  # --- Backup Schedule (opsional) ---
  # Set enable_backup = true untuk aktifkan Azure Backup.
  # Default: false (hemat biaya untuk lab). Set true untuk production.
  enable_backup         = false    # ← set true jika mau backup
  backup_frequency      = "daily"  # daily | weekly | hourly
  backup_start_time     = "02:00"  # UTC (09:00 WIB = 02:00 UTC)
  backup_day_of_week    = "SUNDAY" # hanya untuk weekly
  backup_hours_in_cycle = 6        # 4/6/8/12 jam (hanya untuk hourly)
  backup_retention_days = 7        # minimal 7 hari
}
