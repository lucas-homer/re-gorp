# Development Environment Configuration
# Creates a development k3d cluster with live reload capabilities

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
  cluster_name = "regorp-dev"
  environment  = "development"
}

# Development k3d cluster
module "k3d_cluster" {
  source = "../modules/k3d-cluster"
  
  cluster_name = local.cluster_name
  environment  = local.environment
  
  # Development-specific settings
  server_count = 1
  agent_count  = 2
  api_port     = "6443"
  
  # Port mappings for development services
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
  
  # k3s configuration
  disable_traefik = true
  taint_server    = false  # Allow workloads on server for dev
  
  # Storage settings
  enable_volumes         = true
  storage_path          = "/opt/k3d/${local.cluster_name}"
  storage_class_name    = "local-path"
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

# Development-specific resources
resource "kubernetes_config_map" "tilt_config" {
  depends_on = [module.k3d_cluster]
  
  metadata {
    name      = "tilt-config"
    namespace = module.k3d_cluster.environment_namespace
  }
  
  data = {
    "registry.host" = module.k3d_cluster.registry_endpoint
    "environment"   = local.environment
    "live.reload"   = "true"
    "debug.mode"    = "true"
  }
}

# Development namespace for experimentation
resource "kubernetes_namespace" "sandbox" {
  depends_on = [module.k3d_cluster]
  
  metadata {
    name = "sandbox"
    labels = {
      environment = local.environment
      purpose     = "experimentation"
      managed-by  = "terraform"
    }
  }
}