.PHONY: help dev-setup dev-cluster-setup dev-cluster-destroy clean test test-integration cluster-setup monitoring-deploy app-deploy arc-setup prod-cluster-setup prod-cluster-destroy

# Default target
help:
	@echo "Distributed E-Commerce Platform - Available Commands:"
	@echo ""
	@echo "Development:"
	@echo "  dev-cluster-setup    - Create development k3d cluster with Terraform"
	@echo "  dev-cluster-destroy  - Destroy development k3d cluster"
	@echo "  dev-setup            - Start development environment with Tilt"
	@echo "  clean                - Clean up development environment"
	@echo "  test                 - Run unit tests"
	@echo "  test-integration     - Run integration tests"
	@echo ""
	@echo "Production:"
	@echo "  prod-cluster-setup    - Create production k3d cluster with Terraform"
	@echo "  prod-cluster-destroy  - Destroy production k3d cluster"
	@echo "  cluster-setup         - Set up k3s cluster (legacy)"
	@echo "  monitoring-deploy     - Deploy monitoring stack"
	@echo "  app-deploy           - Deploy application services"
	@echo "  arc-setup            - Set up GitHub Actions Runner Controller"
	@echo ""
	@echo "Management:"
	@echo "  logs             - View service logs"
	@echo "  status           - Check service status"
	@echo "  scale            - Scale services"

# Create development cluster with Terraform
dev-cluster-setup:
	@echo "Creating development k3d cluster with Terraform..."
	cd infrastructure/terraform/development && terraform init
	cd infrastructure/terraform/development && terraform plan
	cd infrastructure/terraform/development && terraform apply -auto-approve
	@echo "Development cluster created! Switch context with:"
	@echo "  kubectl config use-context k3d-regorp-dev"

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

# Destroy development cluster
dev-cluster-destroy:
	@echo "Destroying development k3d cluster..."
	cd infrastructure/terraform/development && terraform destroy -auto-approve
	@echo "Development cluster destroyed!"

# Clean up development environment
clean: dev-cluster-destroy
	@echo "Cleaning up development environment..."
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

# Set up GitHub Actions Runner Controller
arc-setup:
	@echo "Setting up GitHub Actions Runner Controller (ARC)..."
	@echo "Step 1: Installing cert-manager..."
	helm repo add jetstack https://charts.jetstack.io
	helm repo update
	helm upgrade --install cert-manager jetstack/cert-manager \
		--namespace cert-manager --create-namespace \
		--set installCRDs=true
	@echo "Step 2: Installing ARC controller..."
	helm upgrade --install arc \
		--namespace arc-systems --create-namespace \
		oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller
	@echo "Step 3: Waiting for ARC controller to be ready..."
	kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=gha-runner-scale-set-controller \
		--namespace arc-systems --timeout=300s
	@echo "ARC controller installed! Next: Create GitHub App secret and deploy runner scale set."

# Create production k3d cluster
prod-cluster-setup:
	@echo "Creating production k3d cluster with Terraform..."
	cd infrastructure/terraform/production && terraform init
	cd infrastructure/terraform/production && terraform plan
	cd infrastructure/terraform/production && terraform apply -auto-approve
	@echo "Production cluster created! Switch context with:"
	@echo "  kubectl config use-context k3d-regorp-prod"

# Destroy production k3d cluster  
prod-cluster-destroy:
	@echo "Destroying production k3d cluster..."
	cd infrastructure/terraform/production && terraform destroy -auto-approve
	@echo "Production cluster destroyed!"