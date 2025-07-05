# Production Environment Outputs

output "cluster_info" {
  description = "Production cluster information"
  value = {
    name             = module.k3d_cluster.cluster_name
    context          = module.k3d_cluster.kubeconfig_context
    api_endpoint     = module.k3d_cluster.api_endpoint
    registry         = module.k3d_cluster.registry_endpoint
    environment_ns   = module.k3d_cluster.environment_namespace
    storage_class    = module.k3d_cluster.storage_class_name
  }
}

output "production_endpoints" {
  description = "Production service endpoints"
  value = {
    frontend     = "http://localhost:3000"
    api_gateway  = "http://localhost:9080"
    grafana      = "http://localhost:3001"
    registry     = "http://localhost:5000"
    kubernetes   = module.k3d_cluster.api_endpoint
  }
}

output "arc_info" {
  description = "ARC setup information"
  value = {
    github_app_secret_name = module.arc_setup.github_app_secret_name
    arc_namespace         = module.arc_setup.arc_namespace
  }
}

output "next_steps" {
  description = "Next steps for production setup"
  value = [
    "1. Switch kubectl context: kubectl config use-context ${module.k3d_cluster.kubeconfig_context}",
    "2. Verify cluster: kubectl get nodes -o wide",
    "3. Check ARC status: kubectl get pods -n ${module.arc_setup.arc_namespace}",
    "4. Deploy applications: make app-deploy",
    "5. Set up monitoring: Deploy Prometheus/Grafana stack"
  ]
}