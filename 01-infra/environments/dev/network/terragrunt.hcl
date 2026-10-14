# Component: network (VNet + subnet + NAT Gateway + NSG/ASG + private DNS PostgreSQL)
# State terpisah → perubahan di sini tidak men-scan component lain.
#
# SEMUA variabel configurable di-pass eksplisit di sini (AD-2: parameterisasi penuh).
# Peserta cukup edit file INI saja — tidak perlu ubah modules/network/variables.tf.

include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "${get_terragrunt_dir()}/../../../modules/network"
}

locals {
  env = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

# Resource group harus ada lebih dulu (nama diambil dari env.hcl).
dependencies {
  paths = ["../resource-group"]
}

inputs = {
  # --- Identifiers ---
  network_name          = "vnet-course-dev"
  subnet_name           = "snet-course-dev"
  aks_subnet_name       = "snet-aks-dev"
  postgres_subnet_name  = "snet-postgres-dev"
  nat_name              = "nat-course-dev"
  nat_ip_name           = "pip-nat-dev"
  nsg_name              = "nsg-course-dev"
  asg_ssh_name          = "asg-ssh"
  asg_webhook_name      = "asg-webhook"
  firewall_ssh_name     = "allow-ssh"
  firewall_webhook_name = "allow-github-webhook"

  # NAT Gateway & IP-nya zonal — samakan dengan zone node AKS.
  zone = local.env.locals.zone

  # =========================================================================
  # CATATAN SETUP PRODUCTION (NAT Gateway Tuning):
  # =========================================================================
  # Jika terjadi SNAT port exhaustion di Production, tambahkan public IP /
  # public IP prefix ke NAT gateway (1 IP = 64.512 SNAT port).
  # =========================================================================

  # --- Address space ---
  # Pod (10.20.0.0/16) & service (10.30.0.0/20) AKS memakai CIDR overlay di unit aks —
  # JANGAN overlap dengan vnet_cidr.
  vnet_cidr            = "10.10.0.0/16"
  subnet_cidr          = "10.10.0.0/24" # VM (Jenkins)
  postgres_subnet_cidr = "10.10.1.0/24" # delegated PostgreSQL Flexible Server
  aks_subnet_cidr      = "10.10.4.0/22" # node AKS (/22 = 1024 IP)

  postgres_private_dns_zone_name = "course-dev.private.postgres.database.azure.com"

  # --- SSH (padanan IAP) ---
  # Isi IP publik admin agar bisa SSH/Ansible ke VM. Kosong = SSH tertutup.
  ssh_allowed_cidrs = [
    # "YOUR_PUBLIC_IP/32",  # ← GANTI dengan IP admin kamu (curl ifconfig.me)
  ]

  # --- Webhook NSG rule (GitHub webhook IPs + IP admin) ---
  # Ambil dari https://api.github.com/meta → hooks
  # Tambah IP admin kamu untuk akses Jenkins UI via HTTPS
  webhook_allowed_cidrs = [
    "140.82.112.0/20",  # GitHub hooks
    "185.199.108.0/22", # GitHub hooks
    "192.30.252.0/22",  # GitHub hooks
    # "YOUR_PUBLIC_IP/32",  # ← GANTI dengan IP admin kamu
  ]

  # --- Tags ---
  tags = {
    managed_by  = "terraform"
    course      = "be-a-devops-employee"
    environment = "dev"
  }
}
