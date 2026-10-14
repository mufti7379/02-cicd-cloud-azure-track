output "resource_group_name" {
  description = "Nama resource group."
  value       = azurerm_resource_group.main.name
}

output "resource_group_id" {
  description = "Resource ID resource group."
  value       = azurerm_resource_group.main.id
}

output "location" {
  description = "Region resource group."
  value       = azurerm_resource_group.main.location
}
