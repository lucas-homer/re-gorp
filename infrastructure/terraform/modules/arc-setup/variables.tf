# ARC Setup Module Variables

variable "cluster_name" {
  description = "Name of the cluster (used for naming resources)"
  type        = string
}

variable "github_config_url" {
  description = "GitHub repository URL for runners"
  type        = string
  default     = "https://github.com/lucas-homer/re-gorp"
}

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

variable "runner_cpu_request" {
  description = "CPU request for runner containers"
  type        = string
  default     = "100m"
}

variable "runner_memory_request" {
  description = "Memory request for runner containers"
  type        = string
  default     = "128Mi"
}

variable "runner_cpu_limit" {
  description = "CPU limit for runner containers"
  type        = string
  default     = "500m"
}

variable "runner_memory_limit" {
  description = "Memory limit for runner containers"
  type        = string
  default     = "512Mi"
}

variable "node_selector" {
  description = "Node selector for runner pods"
  type        = map(string)
  default = {
    "node-role.kubernetes.io/worker" = "true"
  }
}

variable "tolerations" {
  description = "Tolerations for runner pods"
  type = list(object({
    key      = string
    operator = string
    value    = optional(string)
    effect   = string
  }))
  default = []
}