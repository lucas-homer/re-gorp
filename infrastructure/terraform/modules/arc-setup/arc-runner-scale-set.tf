# ARC Runner Scale Set Configuration
# This deploys the actual runners that will execute GitHub Actions workflows

# Namespace for ARC runners (separate from controller)
resource "kubernetes_namespace" "arc_runners" {
  metadata {
    name = "arc-runners"
  }
}

# Helm release for ARC runner scale set
resource "helm_release" "arc_runner_scale_set" {
  name       = "re-gorp-runners"
  repository = "oci://ghcr.io/actions/actions-runner-controller-charts"
  chart      = "gha-runner-scale-set"
  namespace  = kubernetes_namespace.arc_runners.metadata[0].name

  # Wait for ARC controller to be ready
  depends_on = [kubernetes_secret.github_app_secret]

  # Core configuration values
  values = [
    yamlencode({
      # GitHub repository configuration
      githubConfigUrl = "https://github.com/lucas-homer/re-gorp"
      
      # Authentication via GitHub App
      githubConfigSecret = {
        github_app_id              = var.github_app_id
        github_app_installation_id = var.github_app_installation_id
        github_app_private_key     = var.github_app_private_key
      }

      # Runner scale set configuration
      minRunners = 0  # Scale down to 0 when no jobs
      maxRunners = 5  # Maximum concurrent runners

      # Runner specifications
      template = {
        spec = {
          # Container resources
          containers = [{
            name = "runner"
            image = "ghcr.io/actions/actions-runner:latest"
            resources = {
              requests = {
                cpu    = "100m"
                memory = "128Mi"
              }
              limits = {
                cpu    = "500m"
                memory = "512Mi"
              }
            }
            # Volume mounts for Docker-in-Docker if needed
            volumeMounts = [{
              name      = "work"
              mountPath = "/home/runner/_work"
            }]
          }]
          
          # Volumes
          volumes = [{
            name = "work"
            emptyDir = {}
          }]

          # Node selector for specific nodes if needed
          # nodeSelector = {
          #   "kubernetes.io/arch" = "arm64"
          # }

          # Tolerations for dedicated runner nodes
          # tolerations = [{
          #   key      = "runner"
          #   operator = "Equal"
          #   value    = "true"
          #   effect   = "NoSchedule"
          # }]
        }
      }

      # Controller service account
      controllerServiceAccount = {
        name      = "arc-runner-controller"
        namespace = "arc-systems"
      }

      # Listener configuration
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

  # Timeout for Helm operations
  timeout = 300

  # Wait for pods to be ready
  wait = true
}

# Variables for runner scale set configuration
variable "min_runners" {
  description = "Minimum number of runners"
  type        = number
  default     = 0
}

variable "max_runners" {
  description = "Maximum number of runners"
  type        = number
  default     = 5
}

variable "runner_image" {
  description = "Container image for runners"
  type        = string
  default     = "ghcr.io/actions/actions-runner:latest"
}

# Outputs
output "runner_scale_set_name" {
  description = "Name of the runner scale set"
  value       = helm_release.arc_runner_scale_set.name
}

output "runner_namespace" {
  description = "Namespace where runners are deployed"
  value       = kubernetes_namespace.arc_runners.metadata[0].name
}