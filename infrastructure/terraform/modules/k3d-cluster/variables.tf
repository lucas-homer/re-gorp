# k3d Cluster Module Variables

variable "cluster_name" {
  description = "Name of the k3d cluster"
  type        = string
}

variable "environment" {
  description = "Environment name (development, production, etc.)"
  type        = string
}

variable "server_count" {
  description = "Number of server nodes"
  type        = number
  default     = 1
}

variable "agent_count" {
  description = "Number of agent nodes"
  type        = number
  default     = 2
}

variable "api_port" {
  description = "Port to expose Kubernetes API"
  type        = string
  default     = "6443"
}

variable "port_mappings" {
  description = "Port mappings for the cluster"
  type = list(object({
    port        = string
    nodeFilters = list(string)
  }))
  default = []
}

variable "enable_registry" {
  description = "Enable container registry"
  type        = bool
  default     = true
}

variable "registry_port" {
  description = "Port for container registry"
  type        = string
  default     = "5000"
}

variable "cluster_cidr" {
  description = "CIDR range for pods"
  type        = string
  default     = "10.42.0.0/16"
}

variable "service_cidr" {
  description = "CIDR range for services"
  type        = string
  default     = "10.43.0.0/16"
}

variable "disable_traefik" {
  description = "Disable Traefik ingress controller"
  type        = bool
  default     = true
}

variable "taint_server" {
  description = "Taint server nodes to prevent scheduling workloads"
  type        = bool
  default     = false
}

variable "additional_k3s_args" {
  description = "Additional k3s arguments"
  type = list(object({
    arg         = string
    nodeFilters = list(string)
  }))
  default = []
}

variable "enable_volumes" {
  description = "Enable persistent volumes"
  type        = bool
  default     = true
}

variable "storage_path" {
  description = "Host path for persistent storage"
  type        = string
  default     = "/opt/k3d/storage"
}

variable "storage_class_name" {
  description = "Name of the storage class"
  type        = string
  default     = "local-path"
}

variable "default_storage_class" {
  description = "Make this the default storage class"
  type        = bool
  default     = true
}