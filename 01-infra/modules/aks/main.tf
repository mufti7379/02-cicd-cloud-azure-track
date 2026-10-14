# =============================================================================
# Module: aks
# AKS cluster production-grade (padanan GKE di track GCP):
# - Azure CNI Overlay + Cilium dataplane (padanan Dataplane V2) → Network Policy otomatis
# - Workload Identity (OIDC issuer + federated credential)
# - Entra ID + Azure RBAC untuk akses kubectl (padanan IAM GKE)
# - Authorized IP ranges (hanya IP tertentu bisa kubectl)
# - Max pods/node = 64
# - Node pool autoscaling + spot pool opsional, kubelet identity least-priv (AcrPull di unit acr)
# - Event Grid system topic untuk upgrade notifications (padanan Pub/Sub)
# - Control plane logs → Log Analytics (padanan logging SYSTEM_COMPONENTS)
# - Ingress/App Routing TIDAK diaktifkan (pakai Envoy Gateway sendiri di Epic 9)
#
# Tidak ada padanan langsung (sengaja dilewati):
# - NodeLocal DNSCache, security posture BASIC, cost allocation (butuh tier Standard).
# =============================================================================

data "azurerm_client_config" "current" {}

locals {
  zones = var.zone != "" ? [var.zone] : null
}

# --- Control plane identity (dibuat lebih dulu agar bisa diberi akses ke subnet) ---
resource "azurerm_user_assigned_identity" "cluster" {
  name                = "id-${var.cluster_name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

# Subnet BYO + NAT Gateway: identity cluster butuh Network Contributor di subnet node.
resource "azurerm_role_assignment" "cluster_network" {
  scope                = var.subnet_id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.cluster.principal_id
  principal_type       = "ServicePrincipal"
}

# --- AKS Cluster ---
resource "azurerm_kubernetes_cluster" "main" {
  name                = var.cluster_name
  resource_group_name = var.resource_group_name
  location            = var.location
  dns_prefix          = var.cluster_name
  kubernetes_version  = var.kubernetes_version
  sku_tier            = "Free"
  node_resource_group = "${var.resource_group_name}-${var.cluster_name}-nodes"

  # --- Release channel STABLE + auto-upgrade OS node image ---
  automatic_upgrade_channel = "stable"
  node_os_upgrade_channel   = "NodeImage"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.cluster.id]
  }

  # --- Workload Identity ---
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  # --- Entra ID + Azure RBAC (akses kubectl via `az login` + kubelogin) ---
  azure_active_directory_role_based_access_control {
    azure_rbac_enabled = true
    tenant_id          = data.azurerm_client_config.current.tenant_id
  }

  default_node_pool {
    name                        = var.node_pool_name
    vm_size                     = var.vm_size
    os_disk_size_gb             = var.disk_size_gb
    vnet_subnet_id              = var.subnet_id
    zones                       = local.zones
    max_pods                    = var.max_pods_per_node
    auto_scaling_enabled        = true
    min_count                   = var.min_node_count
    max_count                   = var.max_node_count
    temporary_name_for_rotation = "tmprotation"

    node_labels = merge(var.tags, {
      cluster        = var.cluster_name
      provisioned_by = "terraform"
    })

    upgrade_settings {
      max_surge = "1"
    }

    tags = var.tags
  }

  # --- CNI Overlay + Cilium (padanan Dataplane V2) ---
  # Pod & service memakai CIDR overlay di luar VNet (padanan secondary range GKE).
  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_data_plane  = "cilium"
    network_policy      = "cilium"
    pod_cidr            = var.pod_cidr
    service_cidr        = var.service_cidr
    dns_service_ip      = var.dns_service_ip
    load_balancer_sku   = "standard"
    outbound_type       = "userAssignedNATGateway" # egress lewat NAT Gateway module network
  }

  # --- Authorized IP ranges (security: siapa yang boleh kubectl) ---
  # Kosong = API server terbuka untuk semua IP (tetap butuh autentikasi Entra ID).
  dynamic "api_server_access_profile" {
    for_each = length(var.api_server_authorized_ip_ranges) > 0 ? [1] : []
    content {
      authorized_ip_ranges = var.api_server_authorized_ip_ranges
    }
  }

  # --- VPA ---
  workload_autoscaler_profile {
    vertical_pod_autoscaler_enabled = true
  }

  # --- Azure Disk CSI driver (padanan PD CSI) ---
  storage_profile {
    disk_driver_enabled = true
  }

  # --- Maintenance window (02:00 UTC setiap hari) ---
  maintenance_window_auto_upgrade {
    frequency  = "Daily"
    interval   = 1
    duration   = 4
    start_time = "02:00"
    utc_offset = "+00:00"
  }

  maintenance_window_node_os {
    frequency  = "Daily"
    interval   = 1
    duration   = 4
    start_time = "02:00"
    utc_offset = "+00:00"
  }

  tags = var.tags

  # ⚠️ PROTEKSI DESTROY (AD-18): AKS cluster stateful kritis.
  # AKS tidak punya deletion_protection native; proteksi = prevent_destroy di sini
  # + Azure Policy denyAction dari stage 00-bootstrap.
  # Untuk destroy: comment block ini + matikan policy di 00-bootstrap, lalu apply.
  lifecycle {
    prevent_destroy = true
  }

  depends_on = [azurerm_role_assignment.cluster_network]
}

# --- Spot node pool (opsional, padanan preemptible node GKE) ---
# AKS tidak mengizinkan spot di system (default) pool. Node spot otomatis diberi taint
# kubernetes.azure.com/scalesetpriority=spot:NoSchedule → workload butuh toleration.
resource "azurerm_kubernetes_cluster_node_pool" "spot" {
  count = var.spot_node_pool_enabled ? 1 : 0

  name                  = var.spot_node_pool_name
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = var.spot_vm_size
  os_disk_size_gb       = var.disk_size_gb
  vnet_subnet_id        = var.subnet_id
  zones                 = local.zones
  max_pods              = var.max_pods_per_node

  priority        = "Spot"
  eviction_policy = "Delete"
  spot_max_price  = -1 # bayar maksimal harga on-demand

  auto_scaling_enabled = true
  min_count            = 0
  max_count            = var.spot_max_node_count

  node_labels = {
    "kubernetes.azure.com/scalesetpriority" = "spot"
  }
  node_taints = ["kubernetes.azure.com/scalesetpriority=spot:NoSchedule"]

  tags = var.tags
}

# --- Akses kubectl: Azure RBAC cluster admin ---
# User yang menjalankan Terraform otomatis jadi admin + var.cluster_admin_principal_ids.
resource "azurerm_role_assignment" "cluster_admin" {
  for_each = toset(concat([data.azurerm_client_config.current.object_id], var.cluster_admin_principal_ids))

  scope                = azurerm_kubernetes_cluster.main.id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = each.value
}

# --- Upgrade notifications via Event Grid (padanan Pub/Sub) ---
# Tambahkan event subscription (webhook/email via Logic App, dll) sesuai kebutuhan.
resource "azurerm_eventgrid_system_topic" "upgrades" {
  name                = var.upgrade_notifications_topic
  resource_group_name = var.resource_group_name
  location            = var.location
  source_resource_id  = azurerm_kubernetes_cluster.main.id
  topic_type          = "Microsoft.ContainerService.ManagedClusters"
  tags                = var.tags
}

# --- Control plane logs → Log Analytics (padanan logging SYSTEM_COMPONENTS) ---
resource "azurerm_log_analytics_workspace" "main" {
  count = length(var.control_plane_log_categories) > 0 ? 1 : 0

  name                = "log-${var.cluster_name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
  daily_quota_gb      = 1 # rem biaya: ingest dihentikan setelah 1 GB/hari
  tags                = var.tags
}

resource "azurerm_monitor_diagnostic_setting" "aks" {
  count = length(var.control_plane_log_categories) > 0 ? 1 : 0

  name                       = "diag-${var.cluster_name}"
  target_resource_id         = azurerm_kubernetes_cluster.main.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main[0].id

  dynamic "enabled_log" {
    for_each = toset(var.control_plane_log_categories)
    content {
      category = enabled_log.value
    }
  }
}
