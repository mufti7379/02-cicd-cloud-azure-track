output "network_name" {
  description = "Nama VNet."
  value       = azurerm_virtual_network.main.name
}

output "network_id" {
  description = "Resource ID VNet."
  value       = azurerm_virtual_network.main.id
}

output "subnet_name" {
  description = "Nama subnet VM."
  value       = azurerm_subnet.main.name
}

output "subnet_id" {
  description = "Resource ID subnet VM."
  value       = azurerm_subnet.main.id
}

output "aks_subnet_id" {
  description = "Resource ID subnet node AKS."
  value       = azurerm_subnet.aks.id
}

output "postgres_subnet_id" {
  description = "Resource ID subnet delegated PostgreSQL."
  value       = azurerm_subnet.postgres.id
}

output "postgres_private_dns_zone_id" {
  description = "Resource ID Private DNS zone PostgreSQL."
  value       = azurerm_private_dns_zone.postgres.id
}

output "nat_name" {
  description = "Nama NAT Gateway."
  value       = azurerm_nat_gateway.main.name
}

output "nat_public_ip" {
  description = "IP publik NAT Gateway (egress node AKS) — untuk whitelist di layanan eksternal."
  value       = azurerm_public_ip.nat.ip_address
}

output "nsg_name" {
  description = "Nama NSG subnet VM."
  value       = azurerm_network_security_group.main.name
}

output "application_security_group_ids" {
  description = "Map nama → resource ID ASG (padanan network tags). Dipakai module compute."
  value = {
    ssh     = azurerm_application_security_group.ssh.id
    webhook = azurerm_application_security_group.webhook.id
  }
}
