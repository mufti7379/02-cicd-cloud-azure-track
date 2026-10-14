variable "resource_group_name" {
  type        = string
  description = "Nama resource group cluster."
}

variable "location" {
  type        = string
  description = "Region Azure."
}

variable "zone" {
  type        = string
  description = "Availability zone node pool (1/2/3). Kosongkan agar Azure memilih (non-zonal)."
  default     = ""
}

variable "cluster_name" {
  type        = string
  description = "Nama AKS cluster."
  default     = "aks-course-dev"
}

variable "kubernetes_version" {
  type        = string
  description = "Versi Kubernetes. null = versi default AKS (selanjutnya dikelola auto-upgrade channel stable)."
  default     = null
}

variable "subnet_id" {
  type        = string
  description = "Resource ID subnet node AKS (harus sudah terpasang NAT Gateway)."
}

variable "pod_cidr" {
  type        = string
  description = "CIDR overlay untuk pod (padanan secondary range pods). Tidak boleh overlap VNet."
  default     = "10.20.0.0/16"
}

variable "service_cidr" {
  type        = string
  description = "CIDR untuk Kubernetes service (padanan secondary range services). Tidak boleh overlap VNet."
  default     = "10.30.0.0/20"
}

variable "dns_service_ip" {
  type        = string
  description = "IP CoreDNS, harus berada di dalam service_cidr."
  default     = "10.30.0.10"
}

variable "api_server_authorized_ip_ranges" {
  type        = list(string)
  description = "CIDR yang boleh akses kubectl ke API server (padanan master authorized networks). Kosong = semua IP."
  default     = []
}

variable "max_pods_per_node" {
  type        = number
  description = "Max pods per node. Default 64."
  default     = 64
}

variable "node_pool_name" {
  type        = string
  description = "Nama default (system) node pool. Huruf kecil/angka, maks 12 karakter."
  default     = "coursepool"
}

variable "vm_size" {
  type        = string
  description = "Ukuran VM node pool default (minimal 2 vCPU / 4 GB untuk system pool)."
  default     = "Standard_B2s"
}

variable "disk_size_gb" {
  type        = number
  description = "OS disk size per node (GB)."
  default     = 30
}

variable "min_node_count" {
  type        = number
  description = "Minimum nodes (autoscaling) default pool."
  default     = 1
}

variable "max_node_count" {
  type        = number
  description = "Maximum nodes (autoscaling) default pool."
  default     = 2
}

variable "spot_node_pool_enabled" {
  type        = bool
  description = "Tambahkan node pool spot (padanan preemptible). Node spot di-taint → workload butuh toleration."
  default     = false
}

variable "spot_node_pool_name" {
  type        = string
  description = "Nama spot node pool. Huruf kecil/angka, maks 12 karakter."
  default     = "spot"
}

variable "spot_vm_size" {
  type        = string
  description = "Ukuran VM spot node pool (seri B tidak mendukung Spot)."
  default     = "Standard_D2as_v5"
}

variable "spot_max_node_count" {
  type        = number
  description = "Maximum nodes (autoscaling) spot pool. Minimum selalu 0."
  default     = 3
}

variable "cluster_admin_principal_ids" {
  type        = list(string)
  description = "Object ID Entra tambahan yang diberi Azure Kubernetes Service RBAC Cluster Admin. Pemanggil Terraform otomatis ditambahkan."
  default     = []
}

variable "upgrade_notifications_topic" {
  type        = string
  description = "Nama Event Grid system topic untuk upgrade notifications."
  default     = "aks-upgrade-notifications"
}

variable "control_plane_log_categories" {
  type        = list(string)
  description = "Kategori log control plane yang dikirim ke Log Analytics (mis. kube-apiserver, kube-audit-admin, kube-controller-manager, kube-scheduler, cluster-autoscaler). Kosong = tanpa workspace."
  default     = []
}

variable "tags" {
  type        = map(string)
  description = "Tag umum (juga dipasang sebagai node label)."
  default     = {}
}

variable "enable_destroy_protection" {
  type        = bool
  description = "Toggle destroy protection. AKS tidak punya deletion_protection native: prevent_destroy hardcoded true di main.tf + policy denyAction 00-bootstrap. Variabel ini untuk dokumentasi."
  default     = true
}
