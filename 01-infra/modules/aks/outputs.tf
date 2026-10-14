output "cluster_name" {
  description = "Nama AKS cluster."
  value       = azurerm_kubernetes_cluster.main.name
}

output "cluster_id" {
  description = "Resource ID AKS cluster."
  value       = azurerm_kubernetes_cluster.main.id
}

output "cluster_endpoint" {
  description = "Endpoint API cluster (untuk kubectl)."
  value       = azurerm_kubernetes_cluster.main.kube_config[0].host
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "CA certificate cluster (base64)."
  value       = azurerm_kubernetes_cluster.main.kube_config[0].cluster_ca_certificate
  sensitive   = true
}

output "cluster_location" {
  description = "Region cluster."
  value       = azurerm_kubernetes_cluster.main.location
}

output "get_credentials_command" {
  description = "Perintah az untuk mendapatkan kubectl credentials (Entra ID via kubelogin)."
  value       = "az aks get-credentials --resource-group ${var.resource_group_name} --name ${azurerm_kubernetes_cluster.main.name} && kubelogin convert-kubeconfig -l azurecli"
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL cluster — issuer federated credential Workload Identity (dipakai unit keyvault/postgres)."
  value       = azurerm_kubernetes_cluster.main.oidc_issuer_url
}

output "kubelet_identity_object_id" {
  description = "Object ID kubelet identity node (untuk AcrPull di unit acr)."
  value       = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
}

output "node_resource_group" {
  description = "Resource group yang dikelola AKS untuk VMSS node, load balancer, disk."
  value       = azurerm_kubernetes_cluster.main.node_resource_group
}
