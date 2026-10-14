variable "resource_group_name" {
  type        = string
  description = "Nama resource group Key Vault"
}

variable "location" {
  type        = string
  description = "Lokasi Key Vault (region)"
  default     = "southeastasia"
}

variable "key_vault_name" {
  type        = string
  description = "Nama Key Vault — unik global, 3-24 karakter huruf/angka/tanda hubung"
  default     = "kv-vault-unseal"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]{1,22}[a-zA-Z0-9]$", var.key_vault_name))
    error_message = "key_vault_name harus 3-24 karakter, diawali huruf, hanya huruf/angka/tanda hubung."
  }
}

variable "crypto_key_name" {
  type        = string
  description = "Nama key di Key Vault"
  default     = "vault-unseal-key"
}

variable "identity_name" {
  type        = string
  description = "Nama managed identity untuk Vault"
  default     = "id-vault"
}

variable "oidc_issuer_url" {
  type        = string
  description = "OIDC issuer URL AKS (output unit aks) untuk federated credential Workload Identity"
}

variable "vault_namespace" {
  type        = string
  description = "Namespace Vault di Kubernetes"
  default     = "vault"
}

variable "vault_service_account_name" {
  type        = string
  description = "Nama K8s Service Account Vault"
  default     = "vault"
}

variable "purge_protection_enabled" {
  type        = bool
  description = "Aktifkan purge protection Key Vault (production: true). Tidak bisa dimatikan lagi setelah aktif."
  default     = false
}

variable "tags" {
  type        = map(string)
  description = "Tags untuk resource"
  default     = {}
}
