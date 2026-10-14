# Component: aks (AKS cluster production-grade)
# State terpisah; dependency ke network.
#
# SEMUA variabel configurable di-pass eksplisit di sini (AD-2: parameterisasi penuh).
# Peserta cukup edit file INI saja — tidak perlu ubah modules/aks/variables.tf.

include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "${get_terragrunt_dir()}/../../../modules/aks"
}

locals {
  env = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

dependency "network" {
  config_path = "../network"

  mock_outputs = {
    aks_subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock/providers/Microsoft.Network/virtualNetworks/mock/subnets/mock"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  # --- Cluster config ---
  zone         = local.env.locals.zone
  cluster_name = "aks-course-dev"

  # --- Networking ---
  # Subnet node dari dependency network (sudah terpasang NAT Gateway).
  subnet_id = dependency.network.outputs.aks_subnet_id

  # Pod & service CIDR overlay (padanan secondary range GKE) — JANGAN overlap VNet 10.10.0.0/16.
  pod_cidr       = "10.20.0.0/16" # /16 = 65536 IPs (cegah IP exhaustion)
  service_cidr   = "10.30.0.0/20" # /20 = 4096 IPs (jarang habis)
  dns_service_ip = "10.30.0.10"

  # --- Authorized IP ranges (siapa yang boleh kubectl ke cluster) ---
  # Kosong = semua IP (tetap wajib login Entra ID). Isi IP publik VM Jenkins + IP admin kamu
  # untuk membatasi. Tip: setelah apply network+compute, ambil public IP dari output compute.
  api_server_authorized_ip_ranges = [
    # "103.119.142.178/32", # balifiber
    # "35.247.189.80/32",   # argocd-cluster
  ]

  # --- Node pool config ---
  node_pool_name = "coursepool"   # huruf kecil/angka, maks 12 karakter
  vm_size        = "Standard_B2s" # 2 vCPU / 4 GB (padanan e2-medium)
  disk_size_gb   = 30
  min_node_count = 1
  max_node_count = 5

  # --- Spot node pool (padanan preemptible) ---
  # AKS tidak mengizinkan spot di default pool. Jika true, pool spot tambahan dibuat
  # (min 0 node) dengan taint spot → hanya pod yang punya toleration yang dijadwalkan di sana.
  spot_node_pool_enabled = false
  spot_vm_size           = "Standard_D2as_v5" # seri B tidak mendukung Spot
  spot_max_node_count    = 3

  # --- Max pods per node (cegah IP exhaustion) ---
  max_pods_per_node = 64

  # --- Akses kubectl (Azure RBAC Cluster Admin) ---
  # User yang menjalankan Terraform otomatis jadi admin. Tambah object ID lain jika perlu.
  cluster_admin_principal_ids = []

  # --- Logging (padanan SYSTEM_COMPONENTS) ---
  # Tambah "kube-apiserver" / "kube-audit-admin" jika perlu (volume besar → lebih mahal).
  control_plane_log_categories = ["kube-controller-manager", "kube-scheduler", "cluster-autoscaler"]

  # --- Upgrade notifications ---
  upgrade_notifications_topic = "aks-course-upgrade-notifications"

  # --- Destroy protection (AD-18) ---
  enable_destroy_protection = true # dokumentasi: proteksi = prevent_destroy + policy 00-bootstrap

  # --- Tags ---
  tags = {
    managed_by  = "terraform"
    course      = "be-a-devops-employee"
    environment = "dev"
  }
}
