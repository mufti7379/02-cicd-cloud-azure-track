output "instance_name" {
  description = "Nama VM instance."
  value       = azurerm_linux_virtual_machine.main.name
}

output "instance_id" {
  description = "Resource ID VM instance."
  value       = azurerm_linux_virtual_machine.main.id
}

output "instance_zone" {
  description = "Availability zone tempat VM berjalan."
  value       = azurerm_linux_virtual_machine.main.zone
}

output "instance_internal_ip" {
  description = "IP internal (stabil selama NIC ada — untuk Ansible inventory, referensi antar-service)."
  value       = azurerm_network_interface.main.private_ip_address
}

output "instance_public_ip" {
  description = "IP publik reserved (stabil — untuk DNS, webhook URL, TLS cert). Kosong jika enable_public_ip=false."
  value       = var.enable_public_ip ? azurerm_public_ip.public[0].ip_address : ""
}

output "ssh_command" {
  description = "Perintah SSH ke VM."
  value = (
    var.enable_entra_ssh_login
    ? "az ssh vm --resource-group ${var.resource_group_name} --name ${azurerm_linux_virtual_machine.main.name}"
    : "ssh ${var.admin_username}@${var.enable_public_ip ? azurerm_public_ip.public[0].ip_address : azurerm_network_interface.main.private_ip_address}"
  )
}

output "vm_identity_id" {
  description = "Resource ID managed identity VM."
  value       = azurerm_user_assigned_identity.vm.id
}

output "vm_identity_client_id" {
  description = "Client ID managed identity VM (untuk `az login --identity --client-id`)."
  value       = azurerm_user_assigned_identity.vm.client_id
}

output "vm_identity_principal_id" {
  description = "Object (principal) ID managed identity VM (untuk role assignment di stage/komponen lain)."
  value       = azurerm_user_assigned_identity.vm.principal_id
}
