# Module: acr
# Membuat Azure Container Registry untuk Docker images (padanan Artifact Registry).
# Digunakan oleh CI (Jenkins) untuk push image dan AKS untuk pull image.
# Catatan: ACR tidak punya "repository" eksplisit — repository terbentuk otomatis saat push.
# var.repository_id dipakai sebagai namespace prefix image: <login_server>/<repository_id>/<image>.

resource "azurerm_container_registry" "main" {
  name                = var.registry_name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = var.sku

  # Akses via Entra ID / managed identity, bukan username/password admin.
  admin_enabled = false

  tags = var.tags

  lifecycle {
    prevent_destroy = true # AD-18: jangan hapus registry tanpa disengaja
  }
}

# Cleanup — hapus image lama agar tidak membengkak (padanan cleanup policies).
# ACR Task terjadwal menjalankan `acr purge`:
# - --keep    : pertahankan N tag terbaru per repository
# - --ago     : hapus tag yang lebih tua dari N hari (selain N tag terbaru)
# - --untagged: hapus juga manifest tanpa tag
# Catatan: ACR Tasks tidak tersedia di subscription free trial/credit — set
# enable_cleanup_policy = false jika apply gagal karena itu.
resource "azurerm_container_registry_task" "cleanup" {
  count = var.enable_cleanup_policy ? 1 : 0

  name                  = "purge-old-images"
  container_registry_id = azurerm_container_registry.main.id

  platform {
    os = "Linux"
  }

  encoded_step {
    task_content = base64encode(<<-EOT
      version: v1.1.0
      steps:
        - cmd: acr purge --filter '${var.repository_id}/.*:.*' --keep ${var.keep_count} --ago ${var.untagged_retention_days}d --untagged
          disableWorkingDirectoryOverride: true
          timeout: 3600
    EOT
    )
  }

  timer_trigger {
    name     = "daily"
    schedule = "0 1 * * *" # 01:00 UTC setiap hari
    enabled  = true
  }

  tags = var.tags
}

# IAM: beri kubelet identity AKS akses pull image
resource "azurerm_role_assignment" "aks_pull" {
  count = var.aks_kubelet_principal_id != "" ? 1 : 0

  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = var.aks_kubelet_principal_id
  principal_type       = "ServicePrincipal"
}

# IAM: beri identity VM Jenkins akses push image
resource "azurerm_role_assignment" "jenkins_push" {
  count = var.jenkins_principal_id != "" ? 1 : 0

  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPush"
  principal_id         = var.jenkins_principal_id
  principal_type       = "ServicePrincipal"
}
