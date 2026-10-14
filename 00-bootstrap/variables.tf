variable "subscription_id" {
  type        = string
  description = "ID subscription Azure tempat fondasi dibuat (padanan project_id GCP)."
}

variable "location" {
  type        = string
  description = "Region Azure default (juga lokasi resource group & storage account state)."
  default     = "southeastasia"
}

variable "resource_group_name" {
  type        = string
  description = "Nama resource group untuk resource fondasi (storage account state + identity Terraform)."
  default     = "rg-bootstrap"
}

variable "state_storage_account_name" {
  type        = string
  description = "Nama storage account untuk menyimpan Terraform state stage berikutnya. Harus unik secara global."

  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.state_storage_account_name))
    error_message = "state_storage_account_name harus 3-24 karakter, hanya huruf kecil dan angka."
  }
}

variable "state_container_name" {
  type        = string
  description = "Nama blob container di dalam storage account state."
  default     = "tfstate"
}

variable "resource_providers" {
  type        = list(string)
  description = "Daftar resource provider Azure yang didaftarkan untuk seluruh course (padanan enabled_apis GCP)."
  default = [
    "Microsoft.Compute",          # compute.googleapis.com
    "Microsoft.Network",          # compute.googleapis.com (VPC/firewall) + iap.googleapis.com (Bastion)
    "Microsoft.ContainerService", # container.googleapis.com
    "Microsoft.ManagedIdentity",  # iam.googleapis.com
    "Microsoft.Storage",          # storage.googleapis.com
    "Microsoft.PolicyInsights",   # evaluasi Azure Policy (deny delete, lihat main.tf langkah 6)
  ]
}

variable "terraform_identity_name" {
  type        = string
  description = "Nama user-assigned managed identity yang dipakai Terraform/CI pada stage berikutnya (padanan SA Terraform)."
  default     = "id-terraform"
}

# CATATAN KEAMANAN (AD-18 — anti self-bypass):
# Identity Terraform TIDAK boleh punya Owner, User Access Administrator, atau
# Resource Policy Contributor. Tanpa role itu, identity tidak bisa memodifikasi/menghapus
# policy assignment yang memblokir destroy (Contributor tidak punya Microsoft.Authorization/*/Write).
# Jika butuh manage policy: gunakan akun admin langsung (bukan identity Terraform).
variable "terraform_identity_roles" {
  type        = list(string)
  description = "Role (level subscription) untuk identity Terraform agar bisa provisioning stage berikutnya."
  default = [
    "Contributor", # compute.admin + container.admin + storage.admin + iam.serviceAccountAdmin/User
  ]
}

variable "terraform_assignable_roles" {
  type        = list(string)
  description = "Role yang BOLEH di-assign identity Terraform ke identity lain (padanan roles/resourcemanager.projectIamAdmin, tapi dibatasi via ABAC condition)."
  # Sesuai role yang di-assign module 01-infra (compute, aks, acr, keyvault).
  default = [
    "AcrPull",                                     # artifactregistry.reader (VM Jenkins, kubelet AKS)
    "AcrPush",                                     # artifactregistry.writer (VM Jenkins)
    "Azure Kubernetes Service RBAC Cluster Admin", # container.admin via kubectl (Entra ID RBAC)
    "Key Vault Crypto Officer",                    # pemanggil Terraform membuat key Vault unseal
    "Key Vault Crypto User",                       # cloudkms.cryptoKeyEncrypterDecrypter (Vault auto-unseal)
    "Key Vault Reader",                            # cloudkms.viewer
    "Monitoring Metrics Publisher",                # monitoring.metricWriter
    "Network Contributor",                         # identity AKS atas subnet custom
  ]

  validation {
    condition     = length(var.terraform_assignable_roles) > 0
    error_message = "terraform_assignable_roles minimal berisi 1 role."
  }
}

variable "state_data_contributors" {
  type        = list(string)
  description = "Object ID Entra (user/group/service principal) tambahan yang boleh baca/tulis state (Storage Blob Data Contributor). User yang menjalankan bootstrap otomatis mendapat akses. Padanan impersonator_members GCP."
  default     = []
}

variable "tags" {
  type        = map(string)
  description = "Tag umum untuk resource."
  default = {
    managed_by = "terraform"
    course     = "be-a-devops-employee"
    stage      = "00-bootstrap"
  }
}

variable "enable_destroy_protection" {
  type        = bool
  description = "Toggle prevent_destroy lifecycle pada storage account & container state. prevent_destroy hardcoded true di main.tf; variabel ini untuk dokumentasi."
  default     = true
}

variable "enable_terraform_destroy_deny" {
  type        = bool
  description = "Toggle Azure Policy denyAction yang memblokir delete resource stateful. Default true. Set false HANYA untuk teardown yang disengaja. CATATAN: identity Terraform TIDAK punya hak Microsoft.Authorization/policyAssignments — tidak bisa memodifikasi policy ini sendiri (anti self-bypass)."
  default     = true
}

variable "protected_resource_types" {
  type        = list(string)
  description = "Tipe resource yang tidak boleh di-delete selama enable_terraform_destroy_deny = true."
  default = [
    "Microsoft.Network/virtualNetworks",          # compute.googleapis.com/networks.delete
    "Microsoft.Compute/virtualMachines",          # compute.googleapis.com/instances.delete
    "Microsoft.ContainerService/managedClusters", # container.googleapis.com/clusters.delete
    "Microsoft.Storage/storageAccounts",          # storage.googleapis.com/buckets.delete
  ]
}
