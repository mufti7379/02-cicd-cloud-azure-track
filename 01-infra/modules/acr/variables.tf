variable "resource_group_name" {
  description = "Nama resource group registry"
  type        = string
}

variable "location" {
  description = "Region untuk ACR (misal: southeastasia)"
  type        = string
}

variable "registry_name" {
  description = "Nama ACR — unik global, 5-50 karakter huruf/angka saja (tanpa tanda hubung)"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9]{5,50}$", var.registry_name))
    error_message = "registry_name harus 5-50 karakter huruf/angka saja."
  }
}

variable "sku" {
  description = "SKU ACR: Basic (termurah), Standard, atau Premium"
  type        = string
  default     = "Basic"
}

variable "repository_id" {
  description = "Namespace repository image (prefix path di dalam registry)"
  type        = string
  default     = "docker-images-repo"
}

variable "tags" {
  description = "Tags Azure resource"
  type        = map(string)
  default     = {}
}

variable "enable_cleanup_policy" {
  description = "Aktifkan ACR Task terjadwal (acr purge) untuk hapus image lama"
  type        = bool
  default     = true
}

variable "keep_count" {
  description = "Jumlah tag image terbaru yang dipertahankan per repository"
  type        = number
  default     = 10
}

variable "untagged_retention_days" {
  description = "Jumlah hari image dipertahankan sebelum dihapus (di luar keep_count)"
  type        = number
  default     = 7
}

variable "aks_kubelet_principal_id" {
  description = "Object ID kubelet identity AKS (untuk AcrPull). Kosongkan jika tidak perlu."
  type        = string
  default     = ""
}

variable "jenkins_principal_id" {
  description = "Object ID managed identity VM Jenkins (untuk AcrPush). Kosongkan jika tidak perlu."
  type        = string
  default     = ""
}
