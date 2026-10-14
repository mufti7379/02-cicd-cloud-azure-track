output "key_vault_name" {
  value       = azurerm_key_vault.vault.name
  description = "Nama Key Vault (vault_name di konfigurasi seal azurekeyvault)"
}

output "key_vault_uri" {
  value       = azurerm_key_vault.vault.vault_uri
  description = "URI Key Vault"
}

output "crypto_key_name" {
  value       = azurerm_key_vault_key.vault.name
  description = "Nama key (key_name di konfigurasi seal azurekeyvault)"
}

output "tenant_id" {
  value       = data.azurerm_client_config.current.tenant_id
  description = "Tenant ID Entra (tenant_id di konfigurasi seal azurekeyvault)"
}

output "identity_client_id" {
  value       = azurerm_user_assigned_identity.vault.client_id
  description = "Client ID managed identity Vault (annotation azure.workload.identity/client-id di KSA)"
}

output "kms_key_link" {
  value       = azurerm_key_vault_key.vault.versionless_id
  description = "URL versionless key di Key Vault"
}
