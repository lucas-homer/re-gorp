# GitHub Actions Runner Controller (ARC) Setup Module
# This module sets up the complete ARC infrastructure including controller and runners

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

# ARC Systems namespace
resource "kubernetes_namespace" "arc_systems" {
  metadata {
    name = "arc-systems"
    labels = {
      managed-by = "terraform"
      component  = "arc"
    }
  }
}

# ARC Runners namespace
resource "kubernetes_namespace" "arc_runners" {
  metadata {
    name = "arc-runners"
    labels = {
      managed-by = "terraform"
      component  = "arc"
    }
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

  wait    = true
  timeout = 300
}

# ARC Controller installation
resource "helm_release" "arc_controller" {
  name       = "arc"
  repository = "oci://ghcr.io/actions/actions-runner-controller-charts"
  chart      = "gha-runner-scale-set-controller"
  namespace  = kubernetes_namespace.arc_systems.metadata[0].name

  depends_on = [helm_release.cert_manager]

  wait    = true
  timeout = 300
}

# GitHub App Secret for authentication
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

# ARC Runner Scale Set
resource "helm_release" "arc_runner_scale_set" {
  name       = "${var.cluster_name}-runners"
  repository = "oci://ghcr.io/actions/actions-runner-controller-charts"
  chart      = "gha-runner-scale-set"
  namespace  = kubernetes_namespace.arc_runners.metadata[0].name

  depends_on = [
    helm_release.arc_controller,
    kubernetes_secret.github_app_secret
  ]

  values = [
    yamlencode({
      githubConfigUrl = var.github_config_url
      
      githubConfigSecret = {
        github_app_id              = var.github_app_id
        github_app_installation_id = var.github_app_installation_id
        github_app_private_key     = var.github_app_private_key
      }

      minRunners = var.min_runners
      maxRunners = var.max_runners

      template = {
        spec = {
          containers = [{
            name = "runner"
            image = var.runner_image
            resources = {
              requests = {
                cpu    = var.runner_cpu_request
                memory = var.runner_memory_request
              }
              limits = {
                cpu    = var.runner_cpu_limit
                memory = var.runner_memory_limit
              }
            }
            volumeMounts = [{
              name      = "work"
              mountPath = "/home/runner/_work"
            }]
          }]
          
          volumes = [{
            name = "work"
            emptyDir = {}
          }]

          # Node selector for worker nodes only
          nodeSelector = var.node_selector

          # Tolerations if needed
          tolerations = var.tolerations
        }
      }

      controllerServiceAccount = {
        name      = "arc-runner-controller"
        namespace = kubernetes_namespace.arc_systems.metadata[0].name
      }

      listenerTemplate = {
        spec = {
          containers = [{
            name = "listener"
            resources = {
              requests = {
                cpu    = "50m"
                memory = "64Mi"
              }
              limits = {
                cpu    = "100m"
                memory = "128Mi"
              }
            }
          }]
        }
      }
    })
  ]

  timeout = 300
  wait    = true
}