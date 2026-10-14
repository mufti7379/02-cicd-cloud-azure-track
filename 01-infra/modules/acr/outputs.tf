output "registry_name" {
  description = "Nama ACR"
  value       = azurerm_container_registry.main.name
}

output "registry_id" {
  description = "Resource ID ACR"
  value       = azurerm_container_registry.main.id
}

output "login_server" {
  description = "Login server ACR (untuk docker login / az acr login)"
  value       = azurerm_container_registry.main.login_server
}

output "repository_id" {
  description = "Namespace repository image"
  value       = var.repository_id
}

output "registry_url" {
  description = "URL registry untuk docker push/pull (tanpa nama image & tag)"
  value       = "${azurerm_container_registry.main.login_server}/${var.repository_id}"
}

output "location" {
  description = "Region registry"
  value       = azurerm_container_registry.main.location
}
