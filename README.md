# Distributed E-Commerce Platform

A sophisticated distributed e-commerce platform demonstrating advanced distributed systems patterns, event-driven architecture, and modern DevOps practices.

## 🏗️ Architecture Overview

This platform showcases real-world scalability patterns while maintaining operational simplicity on self-hosted infrastructure.

### Core Services

- **User Service** - Authentication, user profiles, account management
- **Catalog Service** - Product data, search functionality, browsing
- **Inventory Service** - Stock levels, reservations, availability tracking
- **Order Service** - Shopping cart, checkout process, order status
- **Payment Service** - Payment processing (mocked), transaction handling
- **Notification Service** - Email notifications, order updates, alerts

### Technology Stack

- **Container Orchestration**: k3s multi-node (production) / k3d (development)
- **API Gateway**: Apache APISIX
- **Event Streaming**: Redis Streams
- **Data Storage**: PostgreSQL per service, Redis for caching
- **Monitoring**: Prometheus + Grafana
- **CI/CD**: GitHub Actions + ARC
- **Infrastructure**: Terraform + Helm
- **External Access**: Cloudflare Tunnel
- **Development**: Tilt for fast iteration

## 🚀 Quick Start

### Prerequisites

- Docker
- kubectl
- helm
- terraform
- k3d
- tilt

### Local Development Setup

```bash
# Create development cluster with integrated registry
k3d cluster create ecommerce-dev \
  --registry-create ecommerce-registry:5000 \
  --agents 2 \
  --port "8080:80@loadbalancer"

# Start development environment with Tilt
tilt up

# Access the application
# Frontend: http://localhost:3000
# API Gateway: http://localhost:9080
# Grafana: http://localhost:3001
```

## 📁 Project Structure

```
├── services/           # Microservices
│   ├── user-service/
│   ├── catalog-service/
│   ├── inventory-service/
│   ├── order-service/
│   ├── payment-service/
│   └── notification-service/
├── helm/              # Helm charts for services
│   ├── user-service/
│   ├── catalog-service/
│   ├── inventory-service/
│   ├── order-service/
│   ├── payment-service/
│   ├── notification-service/
│   └── api-gateway/
├── infrastructure/     # Infrastructure as Code
│   ├── terraform/
│   └── k8s/
├── monitoring/         # Prometheus & Grafana setup
├── frontend/          # React application
├── Tiltfile           # Development orchestration
└── docs/              # Architecture documentation
```

## 🔄 Event-Driven Architecture

The platform uses Redis Streams for event-driven communication between services:

```
Order Created → Inventory Service (reserve items)
             → Payment Service (process payment)
             → Notification Service (send confirmation)
             → Analytics Service (update metrics)
```

## 🛠️ Development Environment

### Development vs Production

- **Development**: k3d cluster with local registry, Tilt for live updates
- **Production**: k3s multi-node cluster with production registry
- **Parity**: Same Helm charts used for both environments

### Development Workflow

- **Fast iteration** with Tilt live updates and file syncing
- **Realistic image workflow** with local registry push/pull
- **Dependency management** with proper service startup ordering
- **Integrated debugging** with port forwards and log aggregation

## 📊 Monitoring & Observability

- **Prometheus**: Metrics collection and storage
- **Grafana**: Dashboards and visualization
- **Distributed Tracing**: Request flow across services
- **Business Metrics**: Order processing, inventory levels, payment success rates

## 🛠️ Development

### Adding a New Service

1. Create service directory in `services/`
2. Create Helm chart in `helm/`
3. Add Tilt configuration to `Tiltfile`
4. Update API Gateway routing
5. Add monitoring metrics
6. Update event schemas

### Running Tests

```bash
make test
make test-integration
```

## 📈 Production Deployment

### Infrastructure Setup

```bash
# Deploy k3s cluster
make cluster-setup

# Deploy monitoring stack
make monitoring-deploy

# Deploy application services
make app-deploy
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## 📄 License

MIT License - see LICENSE file for details
