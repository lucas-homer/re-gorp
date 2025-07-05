# Development Environment Outputs

output "cluster_info" {
  description = "Development cluster information"
  value = {
    name             = module.k3d_cluster.cluster_name
    context          = module.k3d_cluster.kubeconfig_context
    api_endpoint     = module.k3d_cluster.api_endpoint
    registry         = module.k3d_cluster.registry_endpoint
    environment_ns   = module.k3d_cluster.environment_namespace
    storage_class    = module.k3d_cluster.storage_class_name
  }
}

output "development_endpoints" {
  description = "Development service endpoints"
  value = {
    frontend     = "http://localhost:3000"
    api_gateway  = "http://localhost:9080"
    grafana      = "http://localhost:3001"
    registry     = "http://localhost:5000"
    kubernetes   = module.k3d_cluster.api_endpoint
  }
}

output "next_steps" {
  description = "Next steps for development setup"
  value = [
    "1. Switch kubectl context: kubectl config use-context ${module.k3d_cluster.kubeconfig_context}",
    "2. Verify cluster: kubectl get nodes -o wide",
    "3. Start Tilt development: tilt up",
    "4. Access services at the endpoints above"
  ]
}