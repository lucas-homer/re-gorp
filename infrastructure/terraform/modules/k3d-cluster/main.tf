# k3d Cluster Module
# Creates a k3d cluster with configurable settings for dev/prod environments

# Local file for k3d cluster configuration
resource "local_file" "k3d_config" {
  filename = "${path.module}/k3d-${var.cluster_name}-config.yaml"
  content = yamlencode({
    apiVersion = "k3d.io/v1alpha4"
    kind       = "Simple"
    metadata = {
      name = var.cluster_name
    }
    servers = var.server_count
    agents  = var.agent_count
    
    # Expose cluster API
    kubeAPI = {
      hostIP   = "0.0.0.0"
      hostPort = var.api_port
    }
    
    # Port forwarding for services
    ports = var.port_mappings
    
    # Container registry (optional)
    registries = var.enable_registry ? {
      create = {
        name     = "${var.cluster_name}-registry"
        host     = "0.0.0.0"
        hostPort = var.registry_port
      }
    } : {}
    
    # k3s configuration options
    options = {
      k3s = {
        extraArgs = concat(
          # Base arguments
          [
            {
              arg = "--cluster-cidr=${var.cluster_cidr}"
              nodeFilters = ["server:*"]
            },
            {
              arg = "--service-cidr=${var.service_cidr}"
              nodeFilters = ["server:*"]
            }
          ],
          # Conditional arguments
          var.disable_traefik ? [{
            arg = "--disable=traefik"
            nodeFilters = ["server:*"]
          }] : [],
          var.taint_server ? [{
            arg = "--node-taint=node-role.kubernetes.io/master:NoSchedule"
            nodeFilters = ["server:*"]
          }] : [],
          # Additional custom arguments
          var.additional_k3s_args
        )
      }
      
      # Runtime options
      runtime = {
        labels = [
          {
            label = "environment=${var.environment}"
            nodeFilters = ["all"]
          }
        ]
      }
    }
    
    # Volume mounts for persistent storage
    volumes = var.enable_volumes ? [
      {
        volume = "${var.storage_path}:/var/lib/rancher/k3s/storage"
        nodeFilters = ["all"]
      }
    ] : []
  })
}

# Create the k3d cluster
resource "null_resource" "k3d_cluster_create" {
  depends_on = [local_file.k3d_config]
  
  triggers = {
    config_hash = local_file.k3d_config.content
  }
  
  provisioner "local-exec" {
    command = "k3d cluster create --config ${local_file.k3d_config.filename}"
  }
  
  provisioner "local-exec" {
    when    = destroy
    command = "k3d cluster delete ${var.cluster_name}"
  }
}

# Wait for cluster to be ready and configure
resource "null_resource" "k3d_cluster_ready" {
  depends_on = [null_resource.k3d_cluster_create]
  
  provisioner "local-exec" {
    command = <<-EOF
      # Wait for k3d cluster to be ready
      timeout 120s bash -c 'until kubectl --context k3d-${var.cluster_name} get nodes | grep -q Ready; do sleep 5; done'
      
      # Label nodes for better identification
      kubectl --context k3d-${var.cluster_name} label node k3d-${var.cluster_name}-server-0 node-role.kubernetes.io/control-plane=true --overwrite
      %{for i in range(var.agent_count)}
      kubectl --context k3d-${var.cluster_name} label node k3d-${var.cluster_name}-agent-${i} node-role.kubernetes.io/worker=true --overwrite
      %{endfor}
    EOF
  }
}

# Create storage class if volumes are enabled
resource "kubernetes_storage_class" "local_path" {
  count = var.enable_volumes ? 1 : 0
  depends_on = [null_resource.k3d_cluster_ready]
  
  metadata {
    name = var.storage_class_name
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = var.default_storage_class ? "true" : "false"
    }
  }
  
  storage_provisioner    = "rancher.io/local-path"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true
  
  parameters = {
    hostPath = "/var/lib/rancher/k3s/storage"
  }
}

# Create environment namespace
resource "kubernetes_namespace" "environment" {
  depends_on = [null_resource.k3d_cluster_ready]
  
  metadata {
    name = var.environment
    labels = {
      environment = var.environment
      managed-by  = "terraform"
    }
  }
}