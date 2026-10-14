output "subscription_id" {
  description = "ID subscription Azure tempat fondasi dibuat."
  value       = data.azurerm_subscription.current.subscription_id
}

output "tenant_id" {
  description = "ID tenant Entra ID."
  value       = data.azurerm_client_config.current.tenant_id
}

output "resource_group_name" {
  description = "Resource group storage account state. Pakai ini pada blok backend stage berikutnya."
  value       = azurerm_resource_group.bootstrap.name
}

output "state_storage_account_name" {
  description = "Nama storage account untuk Terraform state. Pakai ini pada blok backend stage berikutnya."
  value       = azurerm_storage_account.tf_state.name
}

output "state_container_name" {
  description = "Nama blob container untuk Terraform state. Pakai ini pada blok backend stage berikutnya."
  value       = azurerm_storage_container.tf_state.name
}

output "terraform_identity_id" {
  description = "Resource ID managed identity Terraform (untuk di-attach ke VM Jenkins/AKS)."
  value       = azurerm_user_assigned_identity.terraform.id
}

output "terraform_identity_client_id" {
  description = "Client ID managed identity Terraform (dipakai `use_msi` / OIDC pada stage berikutnya)."
  value       = azurerm_user_assigned_identity.terraform.client_id
}

output "terraform_identity_principal_id" {
  description = "Object (principal) ID managed identity Terraform."
  value       = azurerm_user_assigned_identity.terraform.principal_id
}

output "registered_resource_providers" {
  description = "Daftar resource provider yang didaftarkan."
  value       = sort(var.resource_providers)
}
