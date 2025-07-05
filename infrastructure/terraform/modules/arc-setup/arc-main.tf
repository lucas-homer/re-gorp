# Main ARC Infrastructure Configuration
# This file orchestrates the complete ARC setup

# Terraform providers
terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
}

# Configure Kubernetes provider for k3d cluster
provider "kubernetes" {
  config_path = "~/.kube/config"
}

# Configure Helm provider
provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

# Cert-manager installation (prerequisite for ARC)
resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  namespace  = "cert-manager"
  create_namespace = true

  set {
    name  = "installCRDs"
    value = "true"
  }

  # Wait for cert-manager to be ready
  wait    = true
  timeout = 300
}

# ARC Controller installation
resource "helm_release" "arc_controller" {
  name       = "arc"
  repository = "oci://ghcr.io/actions/actions-runner-controller-charts"
  chart      = "gha-runner-scale-set-controller"
  namespace  = "arc-systems"
  create_namespace = true

  # Wait for cert-manager to be ready first
  depends_on = [helm_release.cert_manager]

  # Wait for controller to be ready
  wait    = true
  timeout = 300
}

# Data source to wait for ARC controller deployment
data "kubernetes_deployment" "arc_controller" {
  depends_on = [helm_release.arc_controller]
  
  metadata {
    name      = "arc-gha-runner-scale-set-controller"
    namespace = "arc-systems"
  }
}

# Output important information
output "arc_setup_complete" {
  description = "Indicates if ARC setup is complete"
  value       = "ARC Controller and prerequisites installed successfully"
}

output "next_steps" {
  description = "Next steps after ARC installation"
  value = [
    "1. Verify ARC controller is running: kubectl get pods -n arc-systems",
    "2. Check runner scale set status: kubectl get runners -n arc-runners",
    "3. Create a test GitHub Actions workflow to verify functionality"
  ]
}