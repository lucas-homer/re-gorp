# Production Environment Configuration
# Creates a production k3d cluster with ARC and monitoring capabilities

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

# Local variables
locals {
  cluster_name = "regorp-prod"
  environment  = "production"
}

# Variables for GitHub App (passed from terraform.tfvars)
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

# Production k3d cluster
module "k3d_cluster" {
  source = "../modules/k3d-cluster"
  
  cluster_name = local.cluster_name
  environment  = local.environment
  
  # Production-specific settings
  server_count = 1
  agent_count  = 2
  api_port     = "6443"
  
  # Port mappings for production services
  port_mappings = [
    {
      port        = "80:80"
      nodeFilters = ["loadbalancer"]
    },
    {
      port        = "443:443"
      nodeFilters = ["loadbalancer"]
    },
    {
      port        = "9080:9080"
      nodeFilters = ["loadbalancer"]
    },
    {
      port        = "3000:3000"
      nodeFilters = ["loadbalancer"]
    },
    {
      port        = "3001:3001"
      nodeFilters = ["loadbalancer"]
    }
  ]
  
  # Registry settings
  enable_registry = true
  registry_port   = "5000"
  
  # k3s configuration for production
  disable_traefik = true
  taint_server    = true  # Dedicated control plane
  
  # Storage settings
  enable_volumes         = true
  storage_path          = "/opt/k3d/${local.cluster_name}"
  storage_class_name    = "fast-ssd"
  default_storage_class = true
}

# Configure providers to use the cluster
provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = module.k3d_cluster.kubeconfig_context
}

provider "helm" {
  kubernetes {
    config_path    = "~/.kube/config"
    config_context = module.k3d_cluster.kubeconfig_context
  }
}

# Production-specific resources
resource "kubernetes_resource_quota" "production_quota" {
  depends_on = [module.k3d_cluster]
  
  metadata {
    name      = "production-quota"
    namespace = module.k3d_cluster.environment_namespace
  }
  
  spec {
    hard = {
      "requests.cpu"    = "4"
      "requests.memory" = "8Gi"
      "limits.cpu"      = "8"
      "limits.memory"   = "16Gi"
      "pods"           = "50"
    }
  }
}

# Network policy for production security
resource "kubernetes_network_policy" "production_isolation" {
  depends_on = [module.k3d_cluster]
  
  metadata {
    name      = "production-isolation"
    namespace = module.k3d_cluster.environment_namespace
  }
  
  spec {
    pod_selector {}
    
    policy_types = ["Ingress", "Egress"]
    
    # Allow ingress from same namespace
    ingress {
      from {
        namespace_selector {
          match_labels = {
            name = module.k3d_cluster.environment_namespace
          }
        }
      }
    }
    
    # Allow egress to internet and same namespace
    egress {
      # Allow DNS
      ports {
        port     = "53"
        protocol = "UDP"
      }
      ports {
        port     = "53"
        protocol = "TCP"
      }
    }
    
    egress {
      # Allow HTTPS to internet
      ports {
        port     = "443"
        protocol = "TCP"
      }
    }
    
    egress {
      # Allow same namespace
      to {
        namespace_selector {
          match_labels = {
            name = module.k3d_cluster.environment_namespace
          }
        }
      }
    }
  }
}

# ARC Setup Module
module "arc_setup" {
  source = "../modules/arc-setup"
  
  # Wait for cluster to be ready
  depends_on = [module.k3d_cluster]
  
  # Pass GitHub App credentials
  github_app_id              = var.github_app_id
  github_app_installation_id = var.github_app_installation_id
  github_app_private_key     = var.github_app_private_key
}