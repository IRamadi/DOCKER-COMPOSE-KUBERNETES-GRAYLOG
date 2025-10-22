# Graylog Setup with MongoDB and OpenSearch

This repository provides two deployment options for Graylog with MongoDB and OpenSearch:

1. **Option 1: Docker Compose** - Simple setup for development and small deployments
2. **Option 2: Kubernetes** - Production-ready setup with scalability and high availability

## Architecture Overview

### Components

- **Graylog**: Central log management and analysis platform
- **MongoDB**: Database for storing Graylog configuration and metadata
- **OpenSearch**: Search and analytics engine for log data
- **OpenSearch Dashboards**: Web interface for OpenSearch (optional but useful)

### Data Flow

```
Log Sources → Graylog → OpenSearch (for search/analytics)
                ↓
            MongoDB (for configuration/metadata)
```

## Production Credentials Management

### Environment Variables

All sensitive configuration is managed through environment variables. The production team should:

1. **Copy the example file**: `cp .env.example .env`
2. **Edit the .env file** with production values
3. **Use the setup scripts** for automated credential generation

### Available Variables

#### Graylog Configuration
- `GRAYLOG_PASSWORD_SECRET`: Secure random string for Graylog encryption
- `GRAYLOG_ROOT_PASSWORD`: Admin password for Graylog web interface
- `GRAYLOG_ROOT_PASSWORD_SHA2`: SHA256 hash of the admin password
- `GRAYLOG_HTTP_EXTERNAL_URI`: External URL for Graylog (e.g., https://graylog.company.com)

#### MongoDB Configuration
- `MONGODB_ROOT_USERNAME`: MongoDB admin username
- `MONGODB_ROOT_PASSWORD`: MongoDB admin password
- `MONGODB_DATABASE`: Database name for Graylog

#### OpenSearch Configuration
- `OPENSEARCH_CLUSTER_NAME`: OpenSearch cluster name
- `OPENSEARCH_NODE_NAME`: OpenSearch node name
- `OPENSEARCH_DISCOVERY_TYPE`: Discovery type (single-node for development)
- `OPENSEARCH_JAVA_OPTS`: JVM options for OpenSearch

#### Storage and Resources
- `MONGODB_STORAGE_SIZE`: MongoDB persistent volume size
- `OPENSEARCH_STORAGE_SIZE`: OpenSearch persistent volume size
- `GRAYLOG_STORAGE_SIZE`: Graylog persistent volume size
- `GRAYLOG_MEMORY_LIMIT`: Memory limit for Graylog container
- `OPENSEARCH_MEMORY_LIMIT`: Memory limit for OpenSearch container

### Manual Setup

1. **Copy the environment template:**
   ```bash
   cp .env.example .env
   ```

2. **Edit the .env file** with your production values:
   ```bash
   nano .env  # or your preferred editor
   ```

3. **Required changes for production:**
   - Set `GRAYLOG_PASSWORD_SECRET` to a secure random string
   - Set `GRAYLOG_ROOT_PASSWORD` to your desired admin password
   - Generate `GRAYLOG_ROOT_PASSWORD_SHA2` using: `echo -n 'yourpassword' | sha256sum`
   - Set `MONGODB_ROOT_PASSWORD` to a secure password
   - Update `GRAYLOG_HTTP_EXTERNAL_URI` to your domain
   - Adjust storage sizes and resource limits as needed

## Option 1: Docker Compose Setup

### Prerequisites

- Docker Engine 20.10+
- Docker Compose 2.0+
- At least 4GB RAM available
- At least 10GB free disk space

### Quick Start

1. **Configure credentials** (Production teams should do this first)
   ```bash
   # Copy the example environment file
   cp .env.example .env
   
   # Edit .env with your production values
   nano .env  # or your preferred editor
   ```

2. **Start the services**
   ```bash
   docker-compose up -d
   ```

3. **Access Graylog**
   - Open your browser and go to `http://localhost:9000`
   - Default login: `admin` / `admin`

4. **Access OpenSearch Dashboards** (optional)
   - Open your browser and go to `http://localhost:5601`

### Configuration Details

#### Ports Used
- **9000**: Graylog Web Interface
- **9200**: OpenSearch HTTP
- **5601**: OpenSearch Dashboards
- **12201**: GELF (Graylog Extended Log Format) - UDP/TCP
- **1514**: Syslog TCP
- **5555**: Beats input
- **27017**: MongoDB

#### Default Credentials
- **Graylog**: admin / admin
- **MongoDB**: admin / password123

#### Volumes
- `mongodb_data`: MongoDB data persistence
- `opensearch_data`: OpenSearch data persistence
- `graylog_data`: Graylog data persistence

### Customization

#### Change Default Passwords

1. **Graylog Root Password**:
   ```bash
   # Generate SHA256 hash of your password
   echo -n "yourpassword" | sha256sum
   ```
   Update `GRAYLOG_ROOT_PASSWORD_SHA2` in docker-compose.yml

2. **MongoDB Credentials**:
   Update `MONGO_INITDB_ROOT_USERNAME` and `MONGO_INITDB_ROOT_PASSWORD` in docker-compose.yml

#### Resource Limits

Add resource limits to services in docker-compose.yml:
```yaml
services:
  graylog:
    deploy:
      resources:
        limits:
          memory: 2G
        reservations:
          memory: 1G
```

### Troubleshooting

#### Check Service Status
```bash
docker-compose ps
docker-compose logs graylog
docker-compose logs mongodb
docker-compose logs opensearch
```

#### Restart Services
```bash
docker-compose restart graylog
```

#### Clean Restart
```bash
docker-compose down -v
docker-compose up -d
```

## Option 2: Kubernetes Setup

### Prerequisites

- Kubernetes cluster (1.20+)
- kubectl configured
- At least 2 nodes with 4GB RAM each
- Persistent Volume support (or use local storage for testing)

### Quick Start

1. **Configure credentials** (Production teams should do this first)
   ```bash
   # Copy the example environment file
   cp .env.example .env
   
   # Edit .env with your production values
   nano .env  # or your preferred editor
   ```

2. **Create namespace and apply manifests**
   ```bash
   kubectl apply -f k8s/namespace.yaml
   kubectl apply -f k8s/configmap.yaml
   kubectl apply -f k8s/secrets.yaml
   kubectl apply -f k8s/mongodb.yaml
   kubectl apply -f k8s/opensearch.yaml
   kubectl apply -f k8s/graylog.yaml
   ```

2. **Check deployment status**
   ```bash
   kubectl get pods -n graylog
   kubectl get services -n graylog
   ```

3. **Access Graylog**
   ```bash
   # If using LoadBalancer
   kubectl get service graylog -n graylog
   
   # If using NodePort
   kubectl get service graylog-nodeport -n graylog
   # Access via <node-ip>:30090
   ```

### Configuration Details

#### Namespace
All resources are deployed in the `graylog` namespace for isolation.

#### Persistent Volumes
- **MongoDB**: 10Gi storage
- **OpenSearch**: 20Gi storage  
- **Graylog**: 10Gi storage

#### Resource Allocation
- **OpenSearch**: 1-2GB RAM
- **Graylog**: Default (adjust based on needs)
- **MongoDB**: Default (adjust based on needs)

### Production Considerations

#### Security
1. **Change default passwords** in the secrets:
   ```bash
   kubectl edit secret graylog-secret -n graylog
   kubectl edit secret mongodb-secret -n graylog
   ```

2. **Enable TLS/SSL** for all services

3. **Use proper RBAC** for Kubernetes access

#### Scaling
1. **Horizontal Pod Autoscaler** for Graylog:
   ```yaml
   apiVersion: autoscaling/v2
   kind: HorizontalPodAutoscaler
   metadata:
     name: graylog-hpa
     namespace: graylog
   spec:
     scaleTargetRef:
       apiVersion: apps/v1
       kind: Deployment
       name: graylog
     minReplicas: 1
     maxReplicas: 3
     metrics:
     - type: Resource
       resource:
         name: cpu
         target:
           type: Utilization
           averageUtilization: 70
   ```

2. **OpenSearch Cluster** for high availability:
   - Deploy multiple OpenSearch nodes
   - Configure cluster discovery
   - Use dedicated master nodes

#### Monitoring
- Deploy Prometheus and Grafana
- Configure Graylog metrics collection
- Set up alerting for service health

### Troubleshooting

#### Check Pod Status
```bash
kubectl get pods -n graylog
kubectl describe pod <pod-name> -n graylog
```

#### View Logs
```bash
kubectl logs -f deployment/graylog -n graylog
kubectl logs -f deployment/mongodb -n graylog
kubectl logs -f deployment/opensearch -n graylog
```

#### Port Forward for Testing
```bash
kubectl port-forward service/graylog 9000:9000 -n graylog
kubectl port-forward service/opensearch-dashboards 5601:5601 -n graylog
```

## Usage Guide

### Initial Setup

1. **Access Graylog Web Interface**
   - Navigate to the Graylog URL
   - Login with admin/admin (change immediately!)

2. **Configure Inputs**
   - Go to System → Inputs
   - Add GELF UDP input on port 12201
   - Add Syslog TCP input on port 1514

3. **Send Test Logs**
   ```bash
   # GELF format
   echo '{"version": "1.1","host": "test","short_message": "Hello Graylog"}' | nc -u localhost 12201
   
   # Syslog format
   echo '<34>1 2003-10-11T22:14:15.003Z mymachine.example.com su - ID47 - BOM'su root' failed for lonvick on /dev/pts/8' | nc localhost 1514
   ```

### Log Collection Setup

#### From Applications
1. **GELF Libraries**: Use GELF libraries for your programming language
2. **Filebeat**: Configure Filebeat to send to Graylog
3. **Syslog**: Configure applications to send syslog to Graylog

#### From Docker Containers
```yaml
# docker-compose.yml
services:
  your-app:
    image: your-app
    logging:
      driver: gelf
      options:
        gelf-address: "udp://localhost:12201"
        tag: "your-app"
```

### Dashboards and Alerts

1. **Create Dashboards**: Use the search interface to create visualizations
2. **Set up Alerts**: Configure stream rules and alert callbacks
3. **User Management**: Create users and assign roles

## Maintenance

### Backup Strategy

#### Docker Compose
```bash
# Backup volumes
docker run --rm -v graylog_graylog_data:/data -v $(pwd):/backup alpine tar czf /backup/graylog-backup.tar.gz /data
docker run --rm -v graylog_mongodb_data:/data -v $(pwd):/backup alpine tar czf /backup/mongodb-backup.tar.gz /data
docker run --rm -v graylog_opensearch_data:/data -v $(pwd):/backup alpine tar czf /backup/opensearch-backup.tar.gz /data
```

#### Kubernetes
```bash
# Backup using Velero or similar tools
velero backup create graylog-backup --include-namespaces graylog
```

### Updates

#### Docker Compose
```bash
docker-compose pull
docker-compose up -d
```

#### Kubernetes
```bash
kubectl set image deployment/graylog graylog=graylog/graylog:5.2 -n graylog
kubectl rollout status deployment/graylog -n graylog
```

## Security Considerations

### Production Security Checklist

- [ ] Change all default passwords
- [ ] Enable HTTPS/TLS for all services
- [ ] Configure firewall rules
- [ ] Set up proper authentication and authorization
- [ ] Regular security updates
- [ ] Backup and disaster recovery procedures
- [ ] Network segmentation
- [ ] Log monitoring and alerting

### Network Security

1. **Firewall Rules**: Restrict access to necessary ports only
2. **VPN Access**: Use VPN for administrative access
3. **SSL/TLS**: Encrypt all communications
4. **Authentication**: Use strong authentication mechanisms

## Support and Resources

- **Graylog Documentation**: https://docs.graylog.org/
- **OpenSearch Documentation**: https://opensearch.org/docs/
- **MongoDB Documentation**: https://docs.mongodb.com/

## License

This setup uses the following components:
- Graylog: GPL v3
- OpenSearch: Apache 2.0
- MongoDB: Server Side Public License (SSPL)

Please review the licenses before using in production environments.
