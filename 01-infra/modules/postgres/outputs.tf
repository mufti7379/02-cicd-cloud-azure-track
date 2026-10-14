output "instance_name" {
  description = "Nama server PostgreSQL."
  value       = azurerm_postgresql_flexible_server.main.name
}

output "server_fqdn" {
  description = "FQDN server (resolve ke IP privat via Private DNS) — pakai sebagai host koneksi."
  value       = azurerm_postgresql_flexible_server.main.fqdn
}

output "database_name" {
  description = "Nama database default."
  value       = azurerm_postgresql_flexible_server_database.default.name
}

output "iam_db_user" {
  description = "Username PostgreSQL untuk login Entra ID (password = access token)."
  value       = azurerm_user_assigned_identity.db.name
}

output "iam_identity_client_id" {
  description = "Client ID identity DB — isi annotation azure.workload.identity/client-id di KSA aplikasi."
  value       = azurerm_user_assigned_identity.db.client_id
}
