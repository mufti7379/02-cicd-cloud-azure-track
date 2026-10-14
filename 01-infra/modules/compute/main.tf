# =============================================================================
# Module: compute
# VM Linux generik + dedicated Managed Identity (least-privilege) + reserved IP.
# Reusable untuk VM apapun (Jenkins, bastion, app server, dll).
# SSH dibatasi NSG + ASG (IP admin) — lihat module network.
#
# CATATAN SETTINGAN YANG TIDAK BISA DIUBAH TANPA RECREATE VM:
# - zone
# - image, disk_type
# - subnet
# - priority (spot ↔ regular)
# - admin_username, admin_ssh_public_key
# Ubah salah satu di atas = Terraform akan destroy+recreate VM!
# Pastikan settingan ini benar SEBELUM pertama kali apply.
# =============================================================================

data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

locals {
  zones = var.zone != "" ? [var.zone] : null
}

# --- Reserved Static Public IP (stabil untuk DNS, webhook, TLS cert) ---
resource "azurerm_public_ip" "public" {
  count = var.enable_public_ip ? 1 : 0

  name                = "${var.instance_name}-public-ip"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = local.zones

  tags = var.tags
}

# --- NIC (padanan reserved internal IP) ---
# IP privat Azure menempel di NIC dan tidak berubah saat VM stop/deallocate,
# selama NIC tidak dihapus — stabil untuk Ansible & referensi antar-service.
resource "azurerm_network_interface" "main" {
  name                = "${var.instance_name}-nic"
  resource_group_name = var.resource_group_name
  location            = var.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = var.enable_public_ip ? azurerm_public_ip.public[0].id : null
  }

  tags = var.tags
}

# --- Keanggotaan ASG (padanan network tags → target firewall rule) ---
resource "azurerm_network_interface_application_security_group_association" "main" {
  for_each = toset(var.application_security_group_ids)

  network_interface_id          = azurerm_network_interface.main.id
  application_security_group_id = each.value
}

# --- Dedicated Managed Identity (least privilege, generik) ---
resource "azurerm_user_assigned_identity" "vm" {
  name                = var.vm_identity_name
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_role_assignment" "vm_roles" {
  for_each = toset(var.vm_identity_roles)

  scope                = data.azurerm_resource_group.main.id
  role_definition_name = each.value
  principal_id         = azurerm_user_assigned_identity.vm.principal_id
  principal_type       = "ServicePrincipal"
}

# --- VM Instance ---
resource "azurerm_linux_virtual_machine" "main" {
  name                = var.instance_name
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = var.vm_size
  zone                = var.zone != "" ? var.zone : null

  network_interface_ids = [azurerm_network_interface.main.id]

  admin_username                  = var.admin_username
  disable_password_authentication = true
  admin_ssh_key {
    username   = var.admin_username
    public_key = var.admin_ssh_public_key
  }

  os_disk {
    name                 = "${var.instance_name}-osdisk"
    caching              = "ReadWrite"
    storage_account_type = var.disk_type
    disk_size_gb         = var.disk_size_gb
  }

  source_image_reference {
    publisher = var.image.publisher
    offer     = var.image.offer
    sku       = var.image.sku
    version   = var.image.version
  }

  # Dedicated identity (least privilege). System-assigned ditambahkan hanya jika
  # Entra ID SSH login aktif (syarat extension AADSSHLoginForLinux).
  identity {
    type         = var.enable_entra_ssh_login ? "SystemAssigned, UserAssigned" : "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.vm.id]
  }

  # Spot VM (opsional) — jauh lebih murah tapi bisa di-evict kapan saja.
  # Deallocate = VM berhenti (disk & IP tetap), padanan instance_termination_action = STOP.
  priority        = var.preemptible ? "Spot" : "Regular"
  eviction_policy = var.preemptible ? "Deallocate" : null
  max_bid_price   = var.preemptible ? -1 : null # -1 = bayar maksimal harga on-demand

  # Boot diagnostics (managed storage) — syarat Serial Console untuk akses darurat tanpa SSH.
  boot_diagnostics {}

  tags = var.tags

  # ⚠️ PROTEKSI DESTROY (AD-18): VM stateful.
  # Untuk destroy: comment block ini, lalu apply.
  lifecycle {
    prevent_destroy = true
  }
}

# --- Entra ID SSH login (padanan OS Login GCP) ---
# User butuh role "Virtual Machine Administrator Login" / "Virtual Machine User Login",
# lalu SSH via `az ssh vm` — tanpa manage SSH key, ada audit trail.
resource "azurerm_virtual_machine_extension" "entra_ssh_login" {
  count = var.enable_entra_ssh_login ? 1 : 0

  name                       = "AADSSHLoginForLinux"
  virtual_machine_id         = azurerm_linux_virtual_machine.main.id
  publisher                  = "Microsoft.Azure.ActiveDirectory"
  type                       = "AADSSHLoginForLinux"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true

  tags = var.tags
}

# =============================================================================
# Backup Schedule (Azure Backup) — opsional, configurable via variabel.
# Padanan snapshot schedule policy GCP.
# Toggle: var.enable_backup (default false untuk lab, set true untuk production).
# =============================================================================

locals {
  backup_frequency = title(var.backup_frequency)          # daily → Daily
  backup_weekday   = title(lower(var.backup_day_of_week)) # SUNDAY → Sunday
}

resource "azurerm_recovery_services_vault" "backup" {
  count = var.enable_backup ? 1 : 0

  name                = "rsv-${var.instance_name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Standard"
  storage_mode_type   = "LocallyRedundant"

  # Soft delete selalu aktif (secure by default): saat teardown, stop protection +
  # hapus backup data dulu; vault baru bisa dihapus setelah item soft-deleted dibersihkan.

  tags = var.tags
}

resource "azurerm_backup_policy_vm" "backup" {
  count = var.enable_backup ? 1 : 0

  name                = "${var.instance_name}-backup-policy"
  resource_group_name = var.resource_group_name
  recovery_vault_name = azurerm_recovery_services_vault.backup[0].name

  # Hourly hanya didukung Enhanced policy (V2).
  policy_type = var.backup_frequency == "hourly" ? "V2" : "V1"
  timezone    = "UTC"

  backup {
    frequency     = local.backup_frequency
    time          = var.backup_start_time
    weekdays      = var.backup_frequency == "weekly" ? [local.backup_weekday] : null
    hour_interval = var.backup_frequency == "hourly" ? var.backup_hours_in_cycle : null
    hour_duration = var.backup_frequency == "hourly" ? 24 : null
  }

  dynamic "retention_daily" {
    for_each = var.backup_frequency == "weekly" ? [] : [1]
    content {
      count = var.backup_retention_days
    }
  }

  dynamic "retention_weekly" {
    for_each = var.backup_frequency == "weekly" ? [1] : []
    content {
      count    = max(1, ceil(var.backup_retention_days / 7))
      weekdays = [local.backup_weekday]
    }
  }
}

resource "azurerm_backup_protected_vm" "backup" {
  count = var.enable_backup ? 1 : 0

  resource_group_name = var.resource_group_name
  recovery_vault_name = azurerm_recovery_services_vault.backup[0].name
  source_vm_id        = azurerm_linux_virtual_machine.main.id
  backup_policy_id    = azurerm_backup_policy_vm.backup[0].id
}
