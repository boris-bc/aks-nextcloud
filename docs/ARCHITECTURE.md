# Architecture Overview

This document describes the architecture of the Nextcloud deployment on Azure Kubernetes Service.

## Components

### Azure Infrastructure

1. **Resource Group**: Container for all resources
2. **Virtual Network**: Isolated network (10.0.0.0/16)
   - AKS Subnet (10.0.1.0/24)
3. **AKS Cluster**: Kubernetes orchestration
   - Autoscaling: 1-5 nodes
   - VM Size: Standard_D2s_v3
4. **Storage Account**: Azure Files for persistent user data and config
   - User data file share: 100GB (for uploaded files)
   - Config file share: 1GB (for configuration files)
   - Application code remains in container (no rsync overhead)

### Kubernetes Resources

1. **Namespace**: nextcloud
2. **StatefulSets**:
   - MySQL (1 replica) with 20GB persistent volume
3. **Deployments**:
   - Nextcloud (2 replicas)
   - Redis (1 replica)
4. **Services**:
   - LoadBalancer for external access
   - ClusterIP for Redis
   - Headless service for MySQL StatefulSet
5. **Storage**: 
   - PVC with Azure Files for Nextcloud user data (100GB)
   - PVC with Azure Files for Nextcloud config (1GB) 
   - PVC with managed-csi for MySQL data (20GB)
   - Application code remains in container filesystem (fast initialization)
6. **Configuration**: ConfigMaps and Secrets

## Data Flow

1. User → LoadBalancer → Nextcloud Pod
2. Nextcloud → Redis (cache)
3. Nextcloud → MySQL (metadata and database)
4. Nextcloud → Azure Files (user uploaded files + config)

## Security

- VNet isolation
- Managed identities
- Kubernetes secrets
- Database firewall rules
- Encryption at rest and in transit

## Scaling

- Horizontal pod autoscaling
- AKS node autoscaling
- Database vertical scaling

## High Availability

- Multiple Nextcloud pod replicas
- MySQL StatefulSet with persistent storage
- Use Velero for backup/restore
- Zone-redundant storage option for Azure Files
