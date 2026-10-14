variable "resource_group_name" {
  type        = string
  description = "Nama resource group tempat resource jaringan dibuat."
}

variable "location" {
  type        = string
  description = "Region Azure untuk VNet dan NAT."
}

variable "zone" {
  type        = string
  description = "Availability zone untuk NAT Gateway + IP-nya (samakan dengan zone node AKS). Kosongkan untuk non-zonal."
  default     = ""
}

variable "network_name" {
  type        = string
  description = "Nama VNet."
  default     = "vnet-main"
}

variable "vnet_cidr" {
  type        = string
  description = "Address space VNet. Harus mencakup semua subnet di bawah dan TIDAK overlap dengan pod/service CIDR AKS."
  default     = "10.10.0.0/16"
}

variable "subnet_name" {
  type        = string
  description = "Nama subnet VM."
  default     = "snet-main"
}

variable "subnet_cidr" {
  type        = string
  description = "CIDR range untuk subnet VM."
  default     = "10.10.0.0/24"
}

variable "aks_subnet_name" {
  type        = string
  description = "Nama subnet node AKS."
  default     = "snet-aks"
}

variable "aks_subnet_cidr" {
  type        = string
  description = "CIDR subnet node AKS. Dengan CNI Overlay hanya node yang memakai IP di sini; /22 = 1024 IP."
  default     = "10.10.4.0/22"
}

variable "postgres_subnet_name" {
  type        = string
  description = "Nama subnet delegated untuk PostgreSQL Flexible Server."
  default     = "snet-postgres"
}

variable "postgres_subnet_cidr" {
  type        = string
  description = "CIDR subnet delegated PostgreSQL (padanan reserved range Private Service Access)."
  default     = "10.10.1.0/24"
}

variable "postgres_private_dns_zone_name" {
  type        = string
  description = "Nama Private DNS zone PostgreSQL. Wajib berakhiran .postgres.database.azure.com."
  default     = "course.private.postgres.database.azure.com"
}

variable "nat_name" {
  type        = string
  description = "Nama NAT Gateway."
  default     = "nat-main"
}

variable "nat_ip_name" {
  type        = string
  description = "Nama reserved static public IP untuk NAT Gateway."
  default     = "pip-nat-main"
}

variable "nsg_name" {
  type        = string
  description = "Nama Network Security Group untuk subnet VM."
  default     = "nsg-main"
}

variable "asg_ssh_name" {
  type        = string
  description = "Nama Application Security Group untuk VM yang boleh di-SSH (padanan network tag allow-iap-ssh)."
  default     = "asg-ssh"
}

variable "asg_webhook_name" {
  type        = string
  description = "Nama Application Security Group untuk VM penerima webhook (padanan network tag allow-webhook)."
  default     = "asg-webhook"
}

variable "firewall_ssh_name" {
  type        = string
  description = "Nama NSG rule untuk SSH."
  default     = "allow-ssh"
}

variable "firewall_webhook_name" {
  type        = string
  description = "Nama NSG rule untuk GitHub webhook (HTTPS 443)."
  default     = "allow-github-webhook"
}

variable "ssh_allowed_cidrs" {
  type        = list(string)
  description = "CIDR yang boleh SSH (port 22) ke VM di ASG ssh (padanan range IAP). Kosong = SSH tertutup."
  default     = []
}

variable "webhook_allowed_cidrs" {
  type        = list(string)
  description = "CIDR yang boleh akses port 443 (GitHub webhook IPs + IP admin). Ambil dari https://api.github.com/meta -> hooks."
  default = [
    # GitHub hooks (per https://api.github.com/meta, sering berubah — verifikasi sebelum apply)
    "140.82.112.0/20",
    "185.199.108.0/22",
    "192.30.252.0/22",
    # Tambah IP admin kamu di sini:
    # "YOUR_PUBLIC_IP/32",
  ]
}

variable "tags" {
  type        = map(string)
  description = "Tag umum."
  default     = {}
}

variable "enable_destroy_protection" {
  type        = bool
  description = "Toggle untuk prevent_destroy lifecycle pada VNet dan subnet. Default true untuk produksi. Set false HANYA untuk teardown yang disengaja (harus edit kode + apply terlebih dahulu)."
  default     = true
}
