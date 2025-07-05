# GitHub App Secret for ARC Authentication
# This creates a Kubernetes secret containing GitHub App credentials for ARC

resource "kubernetes_namespace" "arc_systems" {
  metadata {
    name = "arc-systems"
  }
}

resource "kubernetes_secret" "github_app_secret" {
  metadata {
    name      = "github-app-secret"
    namespace = kubernetes_namespace.arc_systems.metadata[0].name
  }

  data = {
    github_app_id              = var.github_app_id
    github_app_installation_id = var.github_app_installation_id
    github_app_private_key     = var.github_app_private_key
  }

  type = "Opaque"
}

# Variables for GitHub App credentials
variable "github_app_id" {
  description = "GitHub App ID"
  type        = string
  sensitive   = true
}

variable "github_app_installation_id" {
  description = "GitHub App Installation ID"
  type        = string
  sensitive   = true
}

variable "github_app_private_key" {
  description = "GitHub App Private Key (PEM format)"
  type        = string
  sensitive   = true
}

# Outputs for verification
output "github_app_secret_name" {
  description = "Name of the GitHub App secret"
  value       = kubernetes_secret.github_app_secret.metadata[0].name
}

output "arc_namespace" {
  description = "ARC systems namespace"
  value       = kubernetes_namespace.arc_systems.metadata[0].name
}