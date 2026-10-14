variable "resource_group_name" {
  type        = string
  description = "Nama resource group tempat VM dibuat (juga scope role identity VM)."
}

variable "location" {
  type        = string
  description = "Region Azure untuk VM dan IP."
}

variable "zone" {
  type        = string
  description = "Availability zone VM (1/2/3). Kosongkan untuk non-zonal. ⚠️ TIDAK BISA diubah setelah apply (force recreate)."
  default     = ""
}

variable "instance_name" {
  type        = string
  description = "Nama VM instance."
  default     = "vm-jenkins"
}

variable "vm_size" {
  type        = string
  description = "Ukuran VM. Bisa diubah setelah apply (VM restart). Catatan: seri B tidak mendukung Spot."
  default     = "Standard_D2as_v5"
}

variable "image" {
  type = object({
    publisher = string
    offer     = string
    sku       = string
    version   = string
  })
  description = "Marketplace image untuk OS disk. ⚠️ TIDAK BISA diubah setelah apply (force recreate)."
  default = {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }
}

variable "disk_size_gb" {
  type        = number
  description = "Ukuran OS disk dalam GB (minimal 30 untuk image Ubuntu). Bisa diperbesar (bukan dikecilkan)."
  default     = 30
}

variable "disk_type" {
  type        = string
  description = "Tipe disk. Standard_LRS = HDD (murah), StandardSSD_LRS = SSD standar, Premium_LRS = SSD premium. ⚠️ TIDAK BISA diubah setelah apply."
  default     = "Standard_LRS"
}

variable "preemptible" {
  type        = bool
  description = "Spot VM (jauh lebih murah). ⚠️ TIDAK BISA diubah setelah apply (force recreate). Spot VM bisa di-evict kapan saja."
  default     = true
}

variable "subnet_id" {
  type        = string
  description = "Resource ID subnet tempat VM ditempatkan. ⚠️ TIDAK BISA diubah setelah apply."
}

variable "enable_public_ip" {
  type        = bool
  description = "Aktifkan reserved IP publik (untuk webhook/DNS). IP akan di-reserve (stabil, tidak berubah)."
  default     = true
}

variable "application_security_group_ids" {
  type        = list(string)
  description = "Resource ID ASG tempat NIC VM bergabung (padanan network tags; harus match ASG di NSG rule module network)."
  default     = []
}

variable "vm_identity_name" {
  type        = string
  description = "Nama dedicated user-assigned managed identity VM. Harus unik per resource group."
  default     = "id-vm-instance"
}

variable "vm_identity_roles" {
  type        = list(string)
  description = "Role Azure untuk identity VM di scope resource group (least privilege). Sesuaikan per use-case VM."
  default = [
    "Monitoring Metrics Publisher",
  ]
}

variable "admin_username" {
  type        = string
  description = "Username admin Linux (dipakai Ansible). ⚠️ TIDAK BISA diubah setelah apply."
  default     = "azureuser"
}

variable "admin_ssh_public_key" {
  type        = string
  description = "Isi SSH public key (RSA atau ED25519) untuk admin_username. ⚠️ TIDAK BISA diubah setelah apply."
}

variable "enable_entra_ssh_login" {
  type        = bool
  description = "Aktifkan login SSH via Entra ID (padanan OS Login GCP). TRUE = production-grade, audit trail; FALSE = SSH key biasa."
  default     = false
}

variable "tags" {
  type        = map(string)
  description = "Tag untuk VM dan resources terkait."
  default     = {}
}

variable "enable_destroy_protection" {
  type        = bool
  description = "Toggle destroy protection. prevent_destroy hardcoded true di main.tf; variabel ini untuk dokumentasi."
  default     = true
}

# =============================================================================
# Backup Schedule Variables
# =============================================================================

variable "enable_backup" {
  type        = bool
  description = "Aktifkan Azure Backup untuk VM. Set false untuk lab (hemat biaya), true untuk production."
  default     = false
}

variable "backup_frequency" {
  type        = string
  description = "Frekuensi backup: 'daily', 'weekly', atau 'hourly' (hourly memakai Enhanced policy)."
  default     = "daily"

  validation {
    condition     = contains(["daily", "weekly", "hourly"], var.backup_frequency)
    error_message = "backup_frequency harus salah satu dari: daily, weekly, hourly."
  }
}

variable "backup_start_time" {
  type        = string
  description = "Jam mulai backup (format HH:MM, UTC, kelipatan 30 menit). Default 02:00 UTC (pagi, traffic rendah)."
  default     = "02:00"
}

variable "backup_day_of_week" {
  type        = string
  description = "Hari untuk weekly schedule. Hanya berlaku jika backup_frequency = 'weekly'."
  default     = "SUNDAY"

  validation {
    condition     = contains(["MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY", "SUNDAY"], var.backup_day_of_week)
    error_message = "backup_day_of_week harus hari dalam bahasa Inggris (uppercase)."
  }
}

variable "backup_hours_in_cycle" {
  type        = number
  description = "Interval jam untuk hourly schedule (4, 6, 8, atau 12). Hanya berlaku jika backup_frequency = 'hourly'."
  default     = 6

  validation {
    condition     = contains([4, 6, 8, 12], var.backup_hours_in_cycle)
    error_message = "backup_hours_in_cycle harus 4, 6, 8, atau 12."
  }
}

variable "backup_retention_days" {
  type        = number
  description = "Berapa hari recovery point disimpan (minimal 7). Untuk weekly dibulatkan ke atas per minggu."
  default     = 7

  validation {
    condition     = var.backup_retention_days >= 7
    error_message = "backup_retention_days minimal 7 (batas Azure Backup)."
  }
}
