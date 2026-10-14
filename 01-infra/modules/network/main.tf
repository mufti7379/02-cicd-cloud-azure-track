# =============================================================================
# Module: network
# VNet + subnet (VM, AKS, PostgreSQL) + NAT Gateway + NSG/ASG + private DNS PostgreSQL.
# Pola VNet tunggal (bukan hub-spoke) — disederhanakan untuk course.
#
# Padanan GCP:
# - VPC + subnet            → VNet + subnet per peran (VM, node AKS, PostgreSQL delegated)
# - Secondary range GKE     → tidak perlu; AKS CNI Overlay memakai pod/service CIDR di luar VNet
# - Cloud Router + NAT      → NAT Gateway (dipasang di subnet AKS)
# - Firewall + target tags  → NSG di subnet VM + Application Security Group (ASG)
# - Private Service Access  → subnet delegated + Private DNS zone PostgreSQL
# =============================================================================

locals {
  zones = var.zone != "" ? [var.zone] : null
}

# --- VNet ---
resource "azurerm_virtual_network" "main" {
  name                = var.network_name
  resource_group_name = var.resource_group_name
  location            = var.location
  address_space       = [var.vnet_cidr]
  tags                = var.tags

  # ⚠️ PROTEKSI DESTROY: prevent_destroy hardcoded true (Pendekatan A).
  # Terraform TIDAK menerima variabel di lifecycle.prevent_destroy.
  # Untuk destroy: edit manual block ini (comment/hapus), lalu apply.
  # Lihat RUNBOOK untuk prosedur lengkap.
  lifecycle {
    prevent_destroy = true
  }
}

# --- Subnet VM (Jenkins, dll) ---
resource "azurerm_subnet" "main" {
  name                 = var.subnet_name
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnet_cidr]

  # ⚠️ PROTEKSI DESTROY (AD-18)
  lifecycle {
    prevent_destroy = true
  }
}

# --- Subnet node AKS (pod memakai overlay CIDR, bukan IP subnet ini) ---
resource "azurerm_subnet" "aks" {
  name                 = var.aks_subnet_name
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.aks_subnet_cidr]

  # ⚠️ PROTEKSI DESTROY (AD-18)
  lifecycle {
    prevent_destroy = true
  }
}

# --- Reserved IP untuk NAT Gateway ---
resource "azurerm_public_ip" "nat" {
  name                = var.nat_ip_name
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = local.zones
  tags                = var.tags
}

# --- NAT Gateway (egress node AKS tanpa IP publik per node) ---
# VM dengan IP publik sendiri (Jenkins) tetap egress lewat IP-nya — sama seperti Cloud NAT
# yang tidak dipakai VM ber-external IP. Karena itu NAT hanya dipasang di subnet AKS.
resource "azurerm_nat_gateway" "main" {
  name                    = var.nat_name
  resource_group_name     = var.resource_group_name
  location                = var.location
  sku_name                = "Standard"
  idle_timeout_in_minutes = 4
  zones                   = local.zones
  tags                    = var.tags

  # =========================================================================
  # Catatan Konfigurasi Production:
  # =========================================================================
  # Setiap public IP memberi 64.512 SNAT port. Jika terjadi SNAT port exhaustion
  # (banyak node/koneksi keluar), tambahkan public IP / public IP prefix ke NAT gateway.
  # =========================================================================
}

resource "azurerm_nat_gateway_public_ip_association" "main" {
  nat_gateway_id       = azurerm_nat_gateway.main.id
  public_ip_address_id = azurerm_public_ip.nat.id
}

resource "azurerm_subnet_nat_gateway_association" "aks" {
  subnet_id      = azurerm_subnet.aks.id
  nat_gateway_id = azurerm_nat_gateway.main.id
}

# =============================================================================
# NSG + Application Security Group (padanan firewall rule + network tags GCP).
# VM masuk ke ASG (mis. "ssh", "webhook") lewat NIC-nya di module compute.
# =============================================================================

resource "azurerm_application_security_group" "ssh" {
  name                = var.asg_ssh_name
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_application_security_group" "webhook" {
  name                = var.asg_webhook_name
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_network_security_group" "main" {
  name                = var.nsg_name
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_subnet_network_security_group_association" "main" {
  subnet_id                 = azurerm_subnet.main.id
  network_security_group_id = azurerm_network_security_group.main.id
}

# --- NSG rule: izinkan SSH (22) HANYA dari IP admin ke ASG "ssh" ---
# Padanan firewall IAP SSH. Azure Bastion setara IAP tapi mahal (~$140/bln),
# jadi course ini memakai whitelist IP admin. Kosongkan ssh_allowed_cidrs = SSH tertutup.
resource "azurerm_network_security_rule" "allow_ssh" {
  count = length(var.ssh_allowed_cidrs) > 0 ? 1 : 0

  name                                       = var.firewall_ssh_name
  resource_group_name                        = var.resource_group_name
  network_security_group_name                = azurerm_network_security_group.main.name
  direction                                  = "Inbound"
  priority                                   = 1000
  access                                     = "Allow"
  protocol                                   = "Tcp"
  source_port_range                          = "*"
  destination_port_range                     = "22"
  source_address_prefixes                    = var.ssh_allowed_cidrs
  destination_application_security_group_ids = [azurerm_application_security_group.ssh.id]
}

# --- NSG rule: izinkan HTTPS (443) dari GitHub webhook IPs + admin ---
resource "azurerm_network_security_rule" "allow_github_webhook" {
  name                        = var.firewall_webhook_name
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.main.name
  direction                   = "Inbound"
  priority                    = 900
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"

  # GitHub webhook IP ranges (https://api.github.com/meta -> hooks)
  # Ditambah IP admin untuk akses Jenkins UI via HTTPS
  source_address_prefixes                    = var.webhook_allowed_cidrs
  destination_application_security_group_ids = [azurerm_application_security_group.webhook.id]
}

# --- NSG rule: izinkan HTTP (80) dari anywhere (Let's Encrypt ACME challenge) ---
resource "azurerm_network_security_rule" "allow_http_acme" {
  name                        = "allow-http-acme"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.main.name
  direction                   = "Inbound"
  priority                    = 1010
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"

  # Let's Encrypt validation datang dari IP yang tidak tetap — harus Internet (0.0.0.0/0)
  # HAProxy hanya meneruskan path /.well-known/acme-challenge/ ke certbot;
  # semua traffic lain di-redirect ke HTTPS (terlindungi whitelist di port 443).
  source_address_prefix                      = "Internet"
  destination_application_security_group_ids = [azurerm_application_security_group.webhook.id]
}

# =============================================================================
# Private access untuk PostgreSQL Flexible Server (padanan Private Service Access)
# =============================================================================

# Subnet khusus yang di-delegate ke PostgreSQL Flexible Server
resource "azurerm_subnet" "postgres" {
  name                 = var.postgres_subnet_name
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.postgres_subnet_cidr]

  delegation {
    name = "postgres-flexible-server"
    service_delegation {
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }

  # ⚠️ PROTEKSI DESTROY (AD-18)
  lifecycle {
    prevent_destroy = true
  }
}

# Private DNS zone agar FQDN server PostgreSQL resolve ke IP privat di VNet
resource "azurerm_private_dns_zone" "postgres" {
  name                = var.postgres_private_dns_zone_name
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgres" {
  name                  = "${var.network_name}-postgres-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.postgres.name
  virtual_network_id    = azurerm_virtual_network.main.id
  tags                  = var.tags
}
