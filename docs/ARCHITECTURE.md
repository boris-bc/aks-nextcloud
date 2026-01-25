# Architecture Overview

This document describes the architecture of the Nextcloud deployment on Azure Kubernetes Service.

## Components

### Azure Infrastructure

1. **Resource Group**: Container for all resources
2. **Virtual Network**: Isolated network (10.0.0.0/16)
   - AKS Subnet (10.0.1.0/24)
   - MariaDB Subnet (10.0.2.0/24)
3. **AKS Cluster**: Kubernetes orchestration
   - Autoscaling: 1-5 nodes
   - VM Size: Standard_D2s_v3
4. **MariaDB Flexible Server**: Database backend
   - Version: 14
   - Storage: 32 GB
5. **Storage Account**: Azure Files for persistent data
   - 100 GB file share

### Kubernetes Resources

1. **Namespace**: nextcloud
2. **Deployments**:
   - Nextcloud (2 replicas)
   - Redis (1 replica)
3. **Services**:
   - LoadBalancer for external access
   - ClusterIP for Redis
4. **Storage**: PVC with Azure Files
5. **Configuration**: ConfigMaps and Secrets

## Data Flow

1. User → LoadBalancer → Nextcloud Pod
2. Nextcloud → Redis (cache)
3. Nextcloud → MariaDB (data)
4. Nextcloud → Azure Files (files)

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

- Multiple pod replicas
- MariaDB automated backups
- Zone-redundant storage option
