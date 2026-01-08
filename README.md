# Nextcloud on Azure Kubernetes Service (AKS)

This repository provides a complete setup for deploying Nextcloud on Azure Kubernetes Service (AKS) with PostgreSQL database and Redis caching.

> 🚀 **New to this?** Start with the [Getting Started Guide](GETTING_STARTED.md) for a quick 5-minute deployment!

## Features

- ✅ Production-ready Nextcloud deployment
- ✅ PostgreSQL database for data storage
- ✅ Redis for caching and session management
- ✅ Persistent storage using Azure managed disks
- ✅ LoadBalancer service for external access
- ✅ Optional Ingress with SSL/TLS support
- ✅ Health checks and resource limits
- ✅ Easy deployment and cleanup scripts

## Architecture

```
┌─────────────────────────────────────────────┐
│           Azure Kubernetes Service          │
│                                             │
│  ┌──────────────┐  ┌──────────────┐        │
│  │  Nextcloud   │  │  PostgreSQL  │        │
│  │  Container   │──│  Container   │        │
│  │              │  │              │        │
│  └──────┬───────┘  └──────┬───────┘        │
│         │                 │                 │
│         │   ┌──────────┐  │                 │
│         └───│  Redis   │  │                 │
│             │Container │  │                 │
│             └──────────┘  │                 │
│                           │                 │
│  ┌────────────────────────┴──────────────┐  │
│  │    Azure Managed Disks (Persistent)   │  │
│  └───────────────────────────────────────┘  │
│                                             │
└─────────────┬───────────────────────────────┘
              │
      ┌───────▼────────┐
      │ LoadBalancer / │
      │    Ingress     │
      └────────────────┘
```

## Prerequisites

Before you begin, ensure you have the following:

1. **Azure Account**: An active Azure subscription
2. **Azure CLI**: Installed and configured ([Install Guide](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli))
3. **kubectl**: Kubernetes command-line tool ([Install Guide](https://kubernetes.io/docs/tasks/tools/))
4. **AKS Cluster**: A running AKS cluster

## Quick Start

### Step 1: Create an AKS Cluster

If you don't have an AKS cluster yet, create one:

```bash
# Set variables
RESOURCE_GROUP="nextcloud-rg"
CLUSTER_NAME="nextcloud-aks"
LOCATION="eastus"

# Create resource group
az group create --name $RESOURCE_GROUP --location $LOCATION

# Create AKS cluster
az aks create \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --node-count 2 \
  --node-vm-size Standard_D2s_v3 \
  --enable-managed-identity \
  --generate-ssh-keys

# Get credentials
az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME
```

### Step 2: Configure Secrets

Before deploying, you **must** update the secrets in `k8s/base/secrets.yaml`:

```bash
# Edit the secrets file
nano k8s/base/secrets.yaml
```

Replace the following values:
- `CHANGE_ME_POSTGRES_PASSWORD` - Strong password for PostgreSQL
- `CHANGE_ME_ADMIN_PASSWORD` - Admin password for Nextcloud
- `CHANGE_ME_REDIS_PASSWORD` - Password for Redis

### Step 3: Configure Domain (Optional)

If you want to use a custom domain with Ingress:

1. Edit `k8s/base/configmap.yaml` and update `NEXTCLOUD_TRUSTED_DOMAINS`
2. Edit `k8s/base/nextcloud-ingress.yaml` and update the host field

### Step 4: Deploy Nextcloud

Run the deployment script:

```bash
./deploy.sh
```

The script will:
1. Create the namespace
2. Apply secrets and configuration
3. Create persistent storage
4. Deploy PostgreSQL
5. Deploy Redis
6. Deploy Nextcloud
7. Create the LoadBalancer service

### Step 5: Access Nextcloud

Get the external IP address:

```bash
kubectl get svc -n nextcloud nextcloud-service
```

Access Nextcloud in your browser:
```
http://<EXTERNAL-IP>
```

Login with:
- Username: `admin`
- Password: The password you set in secrets.yaml

## Advanced Configuration

### Using Ingress with SSL/TLS

For production deployments, it's recommended to use an Ingress controller with SSL/TLS:

1. **Install NGINX Ingress Controller**:

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.9.0/deploy/static/provider/cloud/deploy.yaml
```

2. **Install cert-manager** (for automatic SSL certificates):

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
```

3. **Create ClusterIssuer for Let's Encrypt**:

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
```

4. **Deploy the Ingress**:

```bash
kubectl apply -f k8s/base/nextcloud-ingress.yaml
```

### Scaling

To scale Nextcloud horizontally (requires shared storage):

```bash
kubectl scale deployment nextcloud -n nextcloud --replicas=3
```

**Note**: For proper horizontal scaling, you'll need to use Azure Files instead of Azure Disk for the Nextcloud PVC.

### Backup

To backup your Nextcloud data:

```bash
# Backup PostgreSQL database
kubectl exec -n nextcloud deployment/postgres -- pg_dump -U nextcloud nextcloud > nextcloud-db-backup.sql

# For Nextcloud files, backup the PVC
kubectl cp nextcloud/<nextcloud-pod>:/var/www/html ./nextcloud-backup
```

### Monitoring

Check the status of your deployment:

```bash
# View all resources
kubectl get all -n nextcloud

# View pod logs
kubectl logs -n nextcloud -l app=nextcloud -f

# Check pod status
kubectl describe pod -n nextcloud -l app=nextcloud
```

## Storage Configuration

This deployment uses Azure Premium Managed Disks (`managed-premium`) by default:

- **PostgreSQL**: 10Gi
- **Nextcloud**: 50Gi

To use different storage classes or sizes, edit the PVC files in `k8s/base/`.

Available Azure storage classes:
- `default` - Standard HDD
- `managed-premium` - Premium SSD
- `azurefile` - Azure Files (required for ReadWriteMany)

## Troubleshooting

### Pods are not starting

Check pod events:
```bash
kubectl describe pod -n nextcloud <pod-name>
```

Check logs:
```bash
kubectl logs -n nextcloud <pod-name>
```

### Database connection issues

Verify PostgreSQL is running:
```bash
kubectl get pods -n nextcloud -l app=postgres
```

Check database logs:
```bash
kubectl logs -n nextcloud -l app=postgres
```

### Cannot access Nextcloud

Check the service:
```bash
kubectl get svc -n nextcloud
```

Verify the LoadBalancer has an external IP assigned.

### Trusted domain error

Update the ConfigMap with your domain/IP:
```bash
kubectl edit configmap -n nextcloud nextcloud-config
```

Then restart Nextcloud:
```bash
kubectl rollout restart deployment/nextcloud -n nextcloud
```

## Cleanup

To remove all Nextcloud resources:

```bash
./cleanup.sh
```

To delete the AKS cluster:

```bash
az aks delete --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME
az group delete --name $RESOURCE_GROUP
```

## Security Considerations

1. **Always change default passwords** in `secrets.yaml`
2. **Use HTTPS** in production (via Ingress with TLS)
3. **Restrict access** using Network Policies or Azure NSGs
4. **Regular updates**: Keep Nextcloud and dependencies updated
5. **Backup regularly**: Implement automated backup solutions
6. **Enable Azure AD integration** for enterprise authentication

## Resource Requirements

Minimum recommended node size: `Standard_D2s_v3`

Resource allocation:
- Nextcloud: 512Mi-1Gi RAM, 500m-1 CPU
- PostgreSQL: 256Mi-512Mi RAM, 250m-500m CPU
- Redis: 128Mi-256Mi RAM, 100m-200m CPU

## File Structure

```
.
├── README.md
├── deploy.sh                    # Deployment script
├── cleanup.sh                   # Cleanup script
└── k8s/
    └── base/
        ├── namespace.yaml       # Namespace definition
        ├── secrets.yaml         # Secrets (passwords)
        ├── configmap.yaml       # Configuration
        ├── postgres-pvc.yaml    # PostgreSQL storage
        ├── nextcloud-pvc.yaml   # Nextcloud storage
        ├── postgres-deployment.yaml    # PostgreSQL deployment
        ├── redis-deployment.yaml       # Redis deployment
        ├── nextcloud-deployment.yaml   # Nextcloud deployment
        ├── nextcloud-service.yaml      # LoadBalancer service
        └── nextcloud-ingress.yaml      # Ingress (optional)
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is provided as-is for educational and production use.

## Support

For issues and questions:
- Check the [Nextcloud documentation](https://docs.nextcloud.com/)
- Review [AKS documentation](https://docs.microsoft.com/en-us/azure/aks/)
- Open an issue in this repository

## References

- [Nextcloud Docker Hub](https://hub.docker.com/_/nextcloud)
- [Azure Kubernetes Service](https://azure.microsoft.com/en-us/services/kubernetes-service/)
- [Kubernetes Documentation](https://kubernetes.io/docs/home/)