# Distributed E-Commerce Platform - Development Environment
# Tiltfile for orchestrating development with k3d and Helm

load('ext://helm_resource', 'helm_resource', 'helm_repo')

# Use k3d local registry - use IP address accessible from within cluster
default_registry('172.22.0.7:5001')

# Add Helm repositories
helm_repo('bitnami', 'https://charts.bitnami.com/bitnami')
helm_repo('prometheus-community', 'https://prometheus-community.github.io/helm-charts')

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
  chart='./helm/api-gateway',
  flags=['--values', './helm/api-gateway/values-dev.yaml'],
  resource_deps=['redis'],
  port_forwards='9080:9080')

# Microservices with live updates
docker_build('ecommerce/user-service',
  './services/user-service',
  live_update=[
    sync('./services/user-service/src', '/app/src'),
    restart_container(),
  ])

helm_resource('user-service',
  chart='./helm/user-service',
  flags=['--values', './helm/user-service/values-dev.yaml'],
  resource_deps=['redis', 'postgres'],
  port_forwards='3001:3000')

docker_build('ecommerce/catalog-service',
  './services/catalog-service',
  live_update=[
    sync('./services/catalog-service/src', '/app/src'),
    restart_container(),
  ])

helm_resource('catalog-service',
  chart='./helm/catalog-service',
  flags=['--values', './helm/catalog-service/values-dev.yaml'],
  resource_deps=['redis', 'postgres'],
  port_forwards='3002:3000')

docker_build('ecommerce/inventory-service',
  './services/inventory-service',
  live_update=[
    sync('./services/inventory-service/src', '/app/src'),
    restart_container(),
  ])

helm_resource('inventory-service',
  chart='./helm/inventory-service',
  flags=['--values', './helm/inventory-service/values-dev.yaml'],
  resource_deps=['redis', 'postgres'],
  port_forwards='3003:3000')

docker_build('ecommerce/order-service',
  './services/order-service',
  live_update=[
    sync('./services/order-service/src', '/app/src'),
    restart_container(),
  ])

helm_resource('order-service',
  chart='./helm/order-service',
  flags=['--values', './helm/order-service/values-dev.yaml'],
  resource_deps=['redis', 'postgres'],
  port_forwards='3004:3000')

docker_build('ecommerce/payment-service',
  './services/payment-service',
  live_update=[
    sync('./services/payment-service/src', '/app/src'),
    restart_container(),
  ])

helm_resource('payment-service',
  chart='./helm/payment-service',
  flags=['--values', './helm/payment-service/values-dev.yaml'],
  resource_deps=['redis', 'postgres'],
  port_forwards='3005:3000')

docker_build('ecommerce/notification-service',
  './services/notification-service',
  live_update=[
    sync('./services/notification-service/src', '/app/src'),
    restart_container(),
  ])

helm_resource('notification-service',
  chart='./helm/notification-service',
  flags=['--values', './helm/notification-service/values-dev.yaml'],
  resource_deps=['redis', 'postgres'],
  port_forwards='3006:3000')

# Frontend
docker_build('ecommerce/frontend',
  './frontend',
  live_update=[
    sync('./frontend/src', '/app/src'),
    sync('./frontend/public', '/app/public'),
    restart_container(),
  ])

helm_resource('frontend',
  chart='./helm/frontend',
  flags=['--values', './helm/frontend/values-dev.yaml'],
  resource_deps=['api-gateway'],
  port_forwards='3000:3000')

# Monitoring stack
helm_resource('monitoring',
  chart='prometheus-community/kube-prometheus-stack',
  flags=['--values', './monitoring/values-dev.yaml'],
  resource_deps=[],
  port_forwards='3001:3000')  # Grafana

# Development utilities
local_resource('logs',
  'kubectl logs -f deployment/user-service -n services & \
   kubectl logs -f deployment/catalog-service -n services & \
   kubectl logs -f deployment/inventory-service -n services & \
   kubectl logs -f deployment/order-service -n services & \
   kubectl logs -f deployment/payment-service -n services & \
   kubectl logs -f deployment/notification-service -n services',
  resource_deps=['user-service', 'catalog-service', 'inventory-service', 'order-service', 'payment-service', 'notification-service'])

local_resource('status',
  'kubectl get pods -n services && echo "---" && kubectl get pods -n api-gateway && echo "---" && kubectl get pods -n monitoring',
  resource_deps=['user-service', 'catalog-service', 'inventory-service', 'order-service', 'payment-service', 'notification-service', 'api-gateway', 'monitoring'])