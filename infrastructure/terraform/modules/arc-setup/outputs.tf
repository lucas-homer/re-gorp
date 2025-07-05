# ARC Setup Module Outputs

output "arc_controller_namespace" {
  description = "Namespace where ARC controller is deployed"
  value       = kubernetes_namespace.arc_systems.metadata[0].name
}

output "arc_runners_namespace" {
  description = "Namespace where ARC runners are deployed"
  value       = kubernetes_namespace.arc_runners.metadata[0].name
}

output "github_app_secret_name" {
  description = "Name of the GitHub App secret"
  value       = kubernetes_secret.github_app_secret.metadata[0].name
}

output "arc_controller_release_name" {
  description = "Helm release name for ARC controller"
  value       = helm_release.arc_controller.name
}

output "arc_runner_scale_set_name" {
  description = "Helm release name for ARC runner scale set"
  value       = helm_release.arc_runner_scale_set.name
}

output "cert_manager_release_name" {
  description = "Helm release name for cert-manager"
  value       = helm_release.cert_manager.name
}

output "setup_complete" {
  description = "Indicates ARC setup is complete"
  value       = "ARC Controller and Runner Scale Set deployed successfully"
  depends_on = [
    helm_release.cert_manager,
    helm_release.arc_controller,
    helm_release.arc_runner_scale_set
  ]
}