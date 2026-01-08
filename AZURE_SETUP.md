# Azure Kubernetes Service Configuration Guide

## Creating AKS Cluster with Azure CLI

### Basic Cluster Setup

```bash
# Login to Azure
az login

# Set your subscription (if you have multiple)
az account set --subscription "Your Subscription Name"

# Define variables
RESOURCE_GROUP="nextcloud-rg"
CLUSTER_NAME="nextcloud-aks"
LOCATION="eastus"  # Change to your preferred region
NODE_COUNT=2
NODE_SIZE="Standard_D2s_v3"  # 2 vCPU, 8GB RAM

# Create resource group
az group create \
  --name $RESOURCE_GROUP \
  --location $LOCATION

# Create AKS cluster
az aks create \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --node-count $NODE_COUNT \
  --node-vm-size $NODE_SIZE \
  --enable-managed-identity \
  --network-plugin azure \
  --generate-ssh-keys \
  --enable-addons monitoring

# Get cluster credentials
az aks get-credentials \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --overwrite-existing

# Verify connection
kubectl get nodes
```

### Advanced Cluster Setup (Production)

```bash
# Create AKS with more options
az aks create \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --node-count 3 \
  --node-vm-size Standard_D4s_v3 \
  --enable-managed-identity \
  --network-plugin azure \
  --network-policy azure \
  --enable-addons monitoring \
  --enable-cluster-autoscaler \
  --min-count 2 \
  --max-count 5 \
  --zones 1 2 3 \
  --generate-ssh-keys \
  --kubernetes-version 1.28
```

## Node Pool Management

### Add a new node pool

```bash
az aks nodepool add \
  --resource-group $RESOURCE_GROUP \
  --cluster-name $CLUSTER_NAME \
  --name nextcloudpool \
  --node-count 2 \
  --node-vm-size Standard_D4s_v3 \
  --enable-cluster-autoscaler \
  --min-count 2 \
  --max-count 4
```

### Scale node pool

```bash
az aks nodepool scale \
  --resource-group $RESOURCE_GROUP \
  --cluster-name $CLUSTER_NAME \
  --name nodepool1 \
  --node-count 3
```

## Azure Storage Classes

### View available storage classes

```bash
kubectl get storageclass
```

### Create custom storage class for Azure Files (for multi-pod access)

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: azurefile-nextcloud
provisioner: file.csi.azure.com
parameters:
  skuName: Premium_LRS
allowVolumeExpansion: true
mountOptions:
  - dir_mode=0777
  - file_mode=0777
  - uid=0
  - gid=0
  - mfsymlinks
  - cache=strict
```

## Networking

### Install NGINX Ingress Controller

```bash
# Add helm repository
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Install NGINX Ingress
helm install nginx-ingress ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path"=/healthz
```

### Get Ingress external IP

```bash
kubectl get svc -n ingress-nginx
```

## SSL/TLS with cert-manager

### Install cert-manager

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Verify installation
kubectl get pods -n cert-manager
```

### Apply ClusterIssuer

```bash
kubectl apply -f k8s/base/cert-issuer.yaml
```

## Monitoring and Logs

### View cluster metrics

```bash
# Get cluster insights
az aks show \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME

# View node metrics
kubectl top nodes

# View pod metrics
kubectl top pods -n nextcloud
```

### Access Azure Monitor

```bash
# Get monitoring workspace
az aks show \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --query addonProfiles.omsagent.config.logAnalyticsWorkspaceResourceID
```

## Backup and Disaster Recovery

### Backup AKS configuration

```bash
# Export all Kubernetes resources
kubectl get all --all-namespaces -o yaml > aks-backup.yaml
```

### Velero for cluster backups

```bash
# Install Velero for comprehensive backups
# Follow: https://github.com/vmware-tanzu/velero-plugin-for-microsoft-azure
```

## Cost Optimization

### Stop cluster (dev/test only)

```bash
az aks stop \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME
```

### Start cluster

```bash
az aks start \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME
```

### Delete cluster

```bash
az aks delete \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --yes
```

## Troubleshooting

### View cluster events

```bash
kubectl get events --all-namespaces --sort-by='.lastTimestamp'
```

### Access node (for debugging)

```bash
# Create a debug pod
kubectl debug node/<node-name> -it --image=mcr.microsoft.com/dotnet/runtime-deps:6.0
```

### Check cluster health

```bash
kubectl get cs
kubectl cluster-info
az aks show --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME
```

## Security Best Practices

1. **Enable Azure AD integration**:
```bash
az aks update \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --enable-azure-rbac \
  --enable-aad
```

2. **Enable pod security policies** (deprecated, use Pod Security Standards)

3. **Network policies**: Already enabled with `--network-policy azure`

4. **Managed identities**: Already enabled with `--enable-managed-identity`

5. **Private cluster** (optional):
```bash
az aks create \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --enable-private-cluster \
  # ... other options
```

## Useful Commands

```bash
# Get AKS credentials
az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME

# Upgrade cluster
az aks upgrade --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --kubernetes-version 1.28.0

# View available versions
az aks get-versions --location $LOCATION --output table

# Update cluster settings
az aks update --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --enable-cluster-autoscaler

# Get cluster credentials with admin privileges
az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --admin
```
