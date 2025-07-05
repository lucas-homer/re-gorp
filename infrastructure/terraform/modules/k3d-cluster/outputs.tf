# k3d Cluster Module Outputs

output "cluster_name" {
  description = "Name of the k3d cluster"
  value       = var.cluster_name
}

output "kubeconfig_context" {
  description = "kubectl context for the cluster"
  value       = "k3d-${var.cluster_name}"
}

output "registry_endpoint" {
  description = "Container registry endpoint"
  value       = var.enable_registry ? "localhost:${var.registry_port}" : null
}

output "api_endpoint" {
  description = "Kubernetes API endpoint"
  value       = "https://0.0.0.0:${var.api_port}"
}

output "environment_namespace" {
  description = "Environment namespace"
  value       = kubernetes_namespace.environment.metadata[0].name
}

output "storage_class_name" {
  description = "Storage class name"
  value       = var.enable_volumes ? kubernetes_storage_class.local_path[0].metadata[0].name : null
}

output "cluster_ready" {
  description = "Indicates cluster is ready"
  value       = null_resource.k3d_cluster_ready.id
  depends_on  = [null_resource.k3d_cluster_ready]
}