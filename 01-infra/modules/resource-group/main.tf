# =============================================================================
# Module: resource-group
# Wadah semua resource stage 01 per environment.
# Di GCP project sudah menjadi wadah; di Azure setiap resource wajib berada di resource group.
# Provider default `prevent_deletion_if_contains_resources = true` mencegah RG terhapus
# selama masih berisi resource.
# =============================================================================

resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}
