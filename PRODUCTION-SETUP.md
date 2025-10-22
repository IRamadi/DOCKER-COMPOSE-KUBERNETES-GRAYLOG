# Production Setup Guide

This guide provides step-by-step instructions for production teams to configure Graylog with secure credentials.

## Prerequisites

- Docker Engine 20.10+ (for Docker Compose)
- Kubernetes cluster 1.20+ (for Kubernetes)
- kubectl configured (for Kubernetes)

## Step 1: Configure Credentials

### 1.1 Copy Environment Template
```bash
cp .env.example .env
```

### 1.2 Edit Environment File
```bash
nano .env  # or your preferred editor
```

### 1.3 Required Production Changes

#### Graylog Configuration
```bash
# Generate a secure password secret (32+ characters)
GRAYLOG_PASSWORD_SECRET=your-secure-random-string-here

# Set your admin password
GRAYLOG_ROOT_PASSWORD=your-secure-admin-password

# Generate SHA256 hash of your password
# Run: echo -n 'yourpassword' | sha256sum
GRAYLOG_ROOT_PASSWORD_SHA2=generated-sha256-hash-here

# Set your external URL
GRAYLOG_HTTP_EXTERNAL_URI=https://graylog.yourcompany.com/
```

#### MongoDB Configuration
```bash
# Set secure MongoDB credentials
MONGODB_ROOT_USERNAME=admin
MONGODB_ROOT_PASSWORD=your-secure-mongodb-password
MONGODB_DATABASE=graylog
```

#### OpenSearch Configuration
```bash
# Configure OpenSearch cluster
OPENSEARCH_CLUSTER_NAME=graylog
OPENSEARCH_NODE_NAME=graylog-opensearch
OPENSEARCH_DISCOVERY_TYPE=single-node
OPENSEARCH_JAVA_OPTS=-Xms1g -Xmx1g
```

#### Storage and Resources (Adjust based on your needs)
```bash
# Storage sizes
MONGODB_STORAGE_SIZE=10Gi
OPENSEARCH_STORAGE_SIZE=20Gi
GRAYLOG_STORAGE_SIZE=10Gi

# Memory limits
GRAYLOG_MEMORY_LIMIT=2Gi
GRAYLOG_MEMORY_REQUEST=1Gi
OPENSEARCH_MEMORY_LIMIT=2Gi
OPENSEARCH_MEMORY_REQUEST=1Gi
MONGODB_MEMORY_LIMIT=1Gi
MONGODB_MEMORY_REQUEST=512Mi
```

## Step 2: Deploy

### Option A: Docker Compose
```bash
docker-compose up -d
```

### Option B: Kubernetes
```bash
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/secrets.yaml
kubectl apply -f k8s/mongodb.yaml
kubectl apply -f k8s/opensearch.yaml
kubectl apply -f k8s/graylog.yaml
```

## Step 3: Verify Deployment

### Docker Compose
```bash
docker-compose ps
docker-compose logs graylog
```

### Kubernetes
```bash
kubectl get pods -n graylog
kubectl get services -n graylog
kubectl logs -f deployment/graylog -n graylog
```

## Step 4: Access Graylog

- **URL**: `http://localhost:9000` (Docker Compose) or your LoadBalancer/NodePort URL
- **Username**: `admin`
- **Password**: The password you set in `GRAYLOG_ROOT_PASSWORD`

## Security Checklist

- [ ] Changed all default passwords
- [ ] Used strong, unique passwords
- [ ] Set secure `GRAYLOG_PASSWORD_SECRET`
- [ ] Updated `GRAYLOG_HTTP_EXTERNAL_URI` to your domain
- [ ] Configured firewall rules
- [ ] Enabled HTTPS/TLS (recommended)
- [ ] Set up backup procedures
- [ ] Configured monitoring and alerting

## Troubleshooting

### Common Issues

1. **Services not starting**: Check logs with `docker-compose logs` or `kubectl logs`
2. **Connection refused**: Verify all services are running and ports are accessible
3. **Authentication failed**: Double-check your password and SHA256 hash
4. **Storage issues**: Ensure sufficient disk space and proper permissions

### Useful Commands

```bash
# Docker Compose
docker-compose restart graylog
docker-compose down -v  # Clean restart

# Kubernetes
kubectl delete -f k8s/  # Clean restart
kubectl port-forward service/graylog 9000:9000 -n graylog  # Port forward for testing
```

## Next Steps

1. Configure log inputs in Graylog web interface
2. Set up log forwarding from your applications
3. Create dashboards and alerts
4. Configure user accounts and permissions
5. Set up backup and monitoring procedures
