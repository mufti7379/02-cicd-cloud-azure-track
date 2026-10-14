variable "resource_group_name" {
  type        = string
  description = "Nama resource group server PostgreSQL."
}

variable "location" {
  type        = string
  description = "Region Azure."
}

variable "instance_name" {
  type        = string
  description = "Nama server PostgreSQL Flexible Server (unik global — jadi bagian FQDN)."
  default     = "postgres-course-db"
}

variable "database_version" {
  type        = string
  description = "Versi PostgreSQL."
  default     = "15"
}

variable "sku_name" {
  type        = string
  description = "SKU server (<tier>_<size>). B_Standard_B1ms = Burstable termurah (padanan db-f1-micro)."
  default     = "B_Standard_B1ms"
}

variable "storage_mb" {
  type        = number
  description = "Ukuran storage (MB). Minimal 32768."
  default     = 32768
}

variable "delegated_subnet_id" {
  type        = string
  description = "Resource ID subnet yang di-delegate ke Microsoft.DBforPostgreSQL/flexibleServers."
}

variable "private_dns_zone_id" {
  type        = string
  description = "Resource ID Private DNS zone PostgreSQL (ter-link ke VNet)."
}

variable "db_name" {
  type        = string
  description = "Nama database awal."
  default     = "coursedb"
}

variable "iam_identity_name" {
  type        = string
  description = "Nama managed identity yang dibuat untuk akses database (sekaligus username PostgreSQL)."
  default     = "backend-go-db"
}

variable "oidc_issuer_url" {
  type        = string
  description = "OIDC issuer URL AKS (output unit aks) untuk federated credential Workload Identity."
}

variable "k8s_namespace" {
  type        = string
  description = "Namespace Kubernetes tempat aplikasi dideploy."
  default     = "backend-development"
}

variable "k8s_service_account_name" {
  type        = string
  description = "Nama Kubernetes ServiceAccount aplikasi."
  default     = "backend-go"
}

variable "standard_db_user" {
  type        = string
  description = "Username standard password auth (untuk backend-go-cinema). Jadi administrator login server."
  default     = "cinema-user"
}

variable "standard_db_password" {
  type        = string
  description = "Password standard user. Minimal 8 karakter dari 3 kategori (huruf besar, kecil, angka, simbol)."
  sensitive   = true
}

variable "tags" {
  type        = map(string)
  description = "Tag umum."
  default     = {}
}
