.PHONY: help dev-setup dev-cluster deploy clean test test-integration cluster-setup monitoring-deploy app-deploy

# Default target
help:
	@echo "Distributed E-Commerce Platform - Available Commands:"
	@echo ""
	@echo "Development:"
	@echo "  dev-cluster      - Create k3d development cluster"
	@echo "  dev-setup        - Start development environment with Tilt"
	@echo "  deploy           - Deploy all services (production)"
	@echo "  clean            - Clean up development environment"
	@echo "  test             - Run unit tests"
	@echo "  test-integration - Run integration tests"
	@echo ""
	@echo "Production:"
	@echo "  cluster-setup    - Set up k3s cluster"
	@echo "  monitoring-deploy - Deploy monitoring stack"
	@echo "  app-deploy       - Deploy application services"
	@echo ""
	@echo "Management:"
	@echo "  logs             - View service logs"
	@echo "  status           - Check service status"
	@echo "  scale            - Scale services"

# Create development cluster
dev-cluster:
	@echo "Creating image registry..."
	ctlptl create registry regorp-registry --port=5000
	@echo "Creating k3d development cluster..."
	ctlptl create cluster k3d \
		--registry regorp-registry:5000 \
		--agents 2 \
		--port "8080:80@loadbalancer"
	@echo "Development cluster ready!"

# Start development environment with Tilt
dev-setup:
	@echo "Starting development environment with Tilt..."
	tilt up
	@echo "Development environment ready! Access at:"
	@echo "  Frontend: http://localhost:3000"
	@echo "  API Gateway: http://localhost:9080"
	@echo "  Grafana: http://localhost:3001"

# Deploy all services (production)
deploy:
	@echo "Deploying all services to production..."
	helm upgrade --install api-gateway ./helm/api-gateway \
		--namespace api-gateway --create-namespace
	helm upgrade --install services ./helm/services \
		--namespace services --create-namespace
	@echo "Services deployed!"

# Clean up development environment
clean:
	@echo "Cleaning up development environment..."
	k3d cluster delete ecommerce-dev
	docker system prune -f
	@echo "Cleanup complete!"

# Run unit tests
test:
	@echo "Running unit tests..."
	cd services/user-service && npm test
	cd services/catalog-service && npm test
	cd services/inventory-service && npm test
	cd services/order-service && npm test
	cd services/payment-service && npm test
	cd services/notification-service && npm test

# Run integration tests
test-integration:
	@echo "Running integration tests..."
	kubectl apply -f infrastructure/k8s/test-namespace.yaml
	kubectl apply -f infrastructure/k8s/test-services.yaml
	kubectl wait --for=condition=ready pod -l app=test-runner --timeout=300s
	kubectl logs -f job/test-runner
	kubectl delete -f infrastructure/k8s/test-services.yaml
	kubectl delete -f infrastructure/k8s/test-namespace.yaml

# Set up k3s cluster
cluster-setup:
	@echo "Setting up k3s cluster..."
	cd infrastructure/terraform && terraform init
	cd infrastructure/terraform && terraform apply -auto-approve
	@echo "Cluster setup complete!"

# Deploy monitoring stack
monitoring-deploy:
	@echo "Deploying monitoring stack..."
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	helm repo update
	helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
		--namespace monitoring --create-namespace \
		--values infrastructure/monitoring-values.yaml
	@echo "Monitoring stack deployed!"

# Deploy application services
app-deploy:
	@echo "Deploying application services..."
	helm upgrade --install api-gateway ./helm/api-gateway \
		--namespace api-gateway --create-namespace
	helm upgrade --install services ./helm/services \
		--namespace services --create-namespace
	@echo "Application services deployed!"

# View service logs
logs:
	@echo "Viewing service logs..."
	kubectl logs -f deployment/user-service -n services
	kubectl logs -f deployment/catalog-service -n services
	kubectl logs -f deployment/inventory-service -n services
	kubectl logs -f deployment/order-service -n services
	kubectl logs -f deployment/payment-service -n services
	kubectl logs -f deployment/notification-service -n services

# Check service status
status:
	@echo "Checking service status..."
	kubectl get pods -n services
	kubectl get pods -n api-gateway
	kubectl get pods -n monitoring

# Scale services
scale:
	@echo "Scaling services..."
	kubectl scale deployment user-service --replicas=2 -n services
	kubectl scale deployment catalog-service --replicas=2 -n services