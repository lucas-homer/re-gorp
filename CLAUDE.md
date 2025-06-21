# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a distributed e-commerce platform demonstrating advanced distributed systems patterns, event-driven architecture, and modern DevOps practices. The system consists of 6 microservices (User, Catalog, Inventory, Order, Payment, Notification) with a React frontend, orchestrated using Kubernetes (k3d for development, k3s for production).

## Architecture

### Microservices Architecture
- **services/**: Contains 6 Node.js microservices using Express
- **frontend/**: React application using React Router v7 with TypeScript and Vite
- **infrastructure/**: Terraform for infrastructure and Helm charts for deployment
- **helm/**: Service-specific Helm charts with dev/prod value files

### Technology Stack
- **Runtime**: Node.js (services), React (frontend)
- **Data**: PostgreSQL per service, Redis for caching and event streaming
- **Orchestration**: k3d (dev) / k3s (prod) with Helm
- **Development**: Tilt for live development with file syncing
- **Monitoring**: Prometheus + Grafana stack

## Development Commands

### Core Development Workflow
```bash
# Set up development cluster
make dev-cluster

# Start full development environment with live reload
make dev-setup  # Uses tilt up
# OR manually: tilt up

# Access points:
# Frontend: http://localhost:3000
# API Gateway: http://localhost:9080  
# Grafana: http://localhost:3001
```

### Service Development
```bash
# For individual service development (in services/*/):
npm run dev       # Start with nodemon
npm test          # Run unit tests
npm run test:watch # Watch mode tests
npm run lint      # ESLint

# Frontend development (in frontend/):
npm run dev       # React Router dev server
npm run build     # Production build
npm run typecheck # TypeScript checking
```

### Testing & Quality
```bash
make test                # Run all service unit tests
make test-integration    # Run integration tests in k8s
```

### Operations
```bash
make status      # Check all pod status
make logs        # View aggregated service logs
make clean       # Clean up dev environment
make scale       # Scale services to 2 replicas
```

## Development Environment

### Tilt Configuration
- **Live Updates**: File sync for services (`/src`) and frontend (`/app`, `/public`)
- **Container Restart**: Automatic restart on code changes
- **Port Forwards**: Each service exposed on different ports (3001-3006)
- **Dependencies**: Proper startup ordering (redis/postgres → services → frontend)

### Local Registry
- Uses k3d integrated registry at `172.22.0.7:5001`
- All services build and push to local registry for realistic workflow

### Service Dependencies
- **Infrastructure First**: Redis (6379), PostgreSQL (5432)
- **API Gateway**: APISIX on port 9080
- **Service Chain**: Infrastructure → API Gateway → Services → Frontend

## Event-Driven Architecture

Services communicate via Redis Streams for event-driven patterns:
- Order Created → Inventory (reserve) → Payment (process) → Notification (confirm)
- Each service publishes/subscribes to relevant event streams

## File Structure Conventions

### Service Structure (services/*/):
- `src/index.js` - Main entry point
- `package.json` - Standard Node.js with express, pg, redis deps
- `Dockerfile` - Multi-stage builds with health checks

### Helm Charts (helm/*/):
- `Chart.yaml` - Chart metadata
- `templates/` - K8s manifests (deployment.yaml, service.yaml)
- `values-dev.yaml` - Development overrides
- `values.yaml` - Production defaults (if exists)

### Frontend (frontend/):
- React Router v7 application
- `app/` - Application code with routes
- `public/` - Static assets  
- TypeScript configuration with Vite build

## Production Deployment

```bash
# Infrastructure setup
make cluster-setup      # Terraform k3s cluster
make monitoring-deploy  # Prometheus/Grafana stack
make app-deploy        # Application services

# Manual Helm deployments
helm upgrade --install api-gateway ./helm/api-gateway --namespace api-gateway --create-namespace
helm upgrade --install services ./helm/services --namespace services --create-namespace
```

## Key Integration Points

- **API Gateway**: All external traffic routes through APISIX
- **Event Streaming**: Redis Streams for inter-service communication  
- **Database**: Each service has dedicated PostgreSQL database
- **Monitoring**: Prometheus metrics, Grafana dashboards
- **Development**: Tilt orchestrates full stack with live updates