# Distributed E-Commerce Platform - Development Environment
# Tiltfile for orchestrating development with k3d and Helm

load('ext://helm_resource', 'helm_resource', 'helm_repo')
load('ext://restart_process', 'docker_build_with_restart')

# Use k3d local registry - use hostname that k3d provides
default_registry('k3d-regorp-registry.localhost:56414')

# Add Helm repositories
helm_repo('bitnami', 'https://charts.bitnami.com/bitnami')
helm_repo('prometheus-community', 'https://prometheus-community.github.io/helm-charts')
helm_repo('apisix', 'https://charts.apiseven.com/')


# Infrastructure services
helm_resource('redis',
  chart='bitnami/redis',
  flags=['--set', 'auth.enabled=false', '--set', 'architecture=standalone'],
  resource_deps=[],
  port_forwards='6379:6379')

helm_resource('postgres',
  chart='bitnami/postgresql',
  flags=['--set', 'auth.postgresPassword=regorp123', '--set', 'auth.database=regorp'],
  resource_deps=[],
  port_forwards='5432:5432')

# API Gateway
helm_resource('api-gateway',
  'apisix/apisix',
  # flags=['--values', './infrastructure/helm/api-gateway/values-dev.yaml'],
  resource_deps=['redis', 'postgres'],
  port_forwards='9080:9080'
  )

# Microservices with live updates
# docker_build('k3d-regorp-registry.localhost:56414/user-service',
#   './services/user-service',
#   live_update=[
#     sync('./services/user-service/src', '/app/src'),
#     restart_container(),
#   ])

# helm_resource('user-service',
#   chart='./infrastructure/helm/user-service',
#   flags=['--values', './infrastructure/helm/user-service/values-dev.yaml'],
#   resource_deps=['redis', 'postgres'],
#   port_forwards='3001:3000')

# docker_build('regorp/catalog-service',
#   './services/catalog-service',
#   live_update=[
#     sync('./services/catalog-service/src', '/app/src'),
#     restart_container(),
#   ])

# helm_resource('catalog-service',
#   chart='./infrastructure/helm/catalog-service',
#   flags=['--values', './infrastructure/helm/catalog-service/values-dev.yaml'],
#   resource_deps=['redis', 'postgres'],
#   port_forwards='3002:3000')

# docker_build('regorp/inventory-service',
#   './services/inventory-service',
#   live_update=[
#     sync('./services/inventory-service/src', '/app/src'),
#     restart_container(),
#   ])

# helm_resource('inventory-service',
#   chart='./infrastructure/helm/inventory-service',
#   flags=['--values', './infrastructure/helm/inventory-service/values-dev.yaml'],
#   resource_deps=['redis', 'postgres'],
#   port_forwards='3003:3000')

# docker_build('regorp/order-service',
#   './services/order-service',
#   live_update=[
#     sync('./services/order-service/src', '/app/src'),
#     restart_container(),
#   ])

# helm_resource('order-service',
#   chart='./infrastructure/helm/order-service',
#   flags=['--values', './infrastructure/helm/order-service/values-dev.yaml'],
#   resource_deps=['redis', 'postgres'],
#   port_forwards='3004:3000')

# docker_build('regorp/payment-service',
#   './services/payment-service',
#   live_update=[
#     sync('./services/payment-service/src', '/app/src'),
#     restart_container(),
#   ])

# helm_resource('payment-service',
#   chart='./infrastructure/helm/payment-service',
#   flags=['--values', './infrastructure/helm/payment-service/values-dev.yaml'],
#   resource_deps=['redis', 'postgres'],
#   port_forwards='3005:3000')

# docker_build('regorp/notification-service',
#   './services/notification-service',
#   live_update=[
#     sync('./services/notification-service/src', '/app/src'),
#     restart_container(),
#   ])

# helm_resource('notification-service',
#   chart='./infrastructure/helm/notification-service',
#   flags=['--values', './infrastructure/helm/notification-service/values-dev.yaml'],
#   resource_deps=['redis', 'postgres'],
#   port_forwards='3006:3000')


# Frontend
docker_build_with_restart('k3d-regorp-registry.localhost:56414/frontend',
  './frontend',
  entrypoint='npm run start',
  live_update=[
    sync('./frontend/app', '/app/app'),
    sync('./frontend/public', '/app/public'),
  ]
)

# Use `k8s_yaml(helm(` for local charts
k8s_yaml(helm('./infrastructure/helm/frontend', name="frontend", values="./infrastructure/helm/frontend/values-dev.yaml"))
# Port forward the frontend service
k8s_resource('frontend', port_forwards='3000:3000', resource_deps=['api-gateway'])

# Monitoring stack
helm_resource('prometheus',
  chart='prometheus-community/kube-prometheus-stack',
  # flags=['--values', './monitoring/values-dev.yaml'],
  # resource_deps=[],
  )

# Development utilities
# local_resource('logs',
#   'kubectl logs -f deployment/user-service -n services & \
#    kubectl logs -f deployment/catalog-service -n services & \
#    kubectl logs -f deployment/inventory-service -n services & \
#    kubectl logs -f deployment/order-service -n services & \
#    kubectl logs -f deployment/payment-service -n services & \
#    kubectl logs -f deployment/notification-service -n services',
#   resource_deps=['user-service', 'catalog-service', 'inventory-service', 'order-service', 'payment-service', 'notification-service'])

# local_resource('status',
#   'kubectl get pods -n services && echo "---" && kubectl get pods -n api-gateway && echo "---" && kubectl get pods -n monitoring',
#   resource_deps=['user-service', 'catalog-service', 'inventory-service', 'order-service', 'payment-service', 'notification-service', 'api-gateway', 'monitoring'])
