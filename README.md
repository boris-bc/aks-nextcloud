# Nextcloud on Azure Kubernetes Service (AKS)

This repository contains infrastructure as code (IaC) for deploying Nextcloud on Azure Kubernetes Service (AKS) using Terraform and Kubernetes manifests.

## Architecture

The infrastructure includes:

- **Azure Kubernetes Service (AKS)**: Container orchestration platform
- **Azure MariaDB Server**: Database backend for Nextcloud
- **Azure Storage Account**: Persistent storage for Nextcloud data using Azure Files
- **Azure Virtual Network**: Network isolation and security
- **Redis**: In-memory cache for improved performance
- **Kubernetes Resources**: 
  - Nextcloud application deployment
  - Redis deployment for caching
  - Persistent Volume Claims for data storage
  - Services and Ingress for external access

## Prerequisites

- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) (>= 2.30)
- [Terraform](https://www.terraform.io/downloads.html) (>= 1.0)
- [kubectl](https://kubernetes.io/docs/tasks/tools/) (>= 1.24)
- [kustomize](https://kustomize.io/) (>= 4.0) - optional, for Kustomize-based deployments
- Azure subscription with appropriate permissions

## Quick Start

### 1. Deploy Infrastructure with Terraform

```bash
# Login to Azure
az login

# Navigate to terraform directory
cd terraform

# Copy example variables file
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your desired configuration
vim terraform.tfvars

# Initialize Terraform
terraform init

# Review the planned changes
terraform plan

# Apply the configuration
terraform apply
```

### 2. Configure kubectl

```bash
# Get AKS credentials
az aks get-credentials --resource-group <resource-group-name> --name <aks-cluster-name>

# Verify connection
kubectl get nodes
```

### 3. Update Kubernetes Secrets

After Terraform completes, update the secrets with actual values:

```bash
# Get Terraform outputs
terraform output -json > outputs.json

# Extract values (example using jq)
POSTGRES_FQDN=$(terraform output -raw mysql_fqdn)
POSTGRES_PASSWORD=$(terraform output -raw mysql_admin_password)
STORAGE_ACCOUNT_NAME=$(terraform output -raw storage_account_name)
STORAGE_ACCOUNT_KEY=$(terraform output -raw storage_account_key)

# Update secrets file
cd ../kubernetes/base
# Edit secrets.yaml and replace placeholder values
```

Or use a script to generate secrets:

```bash
# Example: Create secrets from Terraform outputs
kubectl create secret generic nextcloud-db \
  --from-literal=db-host="$POSTGRES_FQDN" \
  --from-literal=db-name="nextcloud" \
  --from-literal=db-username="nextcloudadmin" \
  --from-literal=db-password="$POSTGRES_PASSWORD" \
  --namespace=nextcloud --dry-run=client -o yaml > secrets-db.yaml

kubectl create secret generic azure-storage \
  --from-literal=azurestorageaccountname="$STORAGE_ACCOUNT_NAME" \
  --from-literal=azurestorageaccountkey="$STORAGE_ACCOUNT_KEY" \
  --namespace=nextcloud --dry-run=client -o yaml > secrets-storage.yaml
```

### 4. Deploy Nextcloud to Kubernetes

#### Option A: Using kubectl

```bash
cd kubernetes/base

# Create namespace
kubectl apply -f namespace.yaml

# Apply all resources
kubectl apply -f .
```

#### Option B: Using Kustomize (Recommended)

For development environment:
```bash
cd kubernetes/overlays/dev
kubectl apply -k .
```

For production environment:
```bash
cd kubernetes/overlays/prod
kubectl apply -k .
```

### 5. Access Nextcloud

```bash
# Get the external IP address
kubectl get service nextcloud -n nextcloud

# Wait for EXTERNAL-IP to be assigned
# Access Nextcloud at http://<EXTERNAL-IP>
```

For production with Ingress:
1. Install an Ingress controller (e.g., NGINX Ingress Controller)
2. Install cert-manager for TLS certificates
3. **Important:** Update the Ingress resource in `kubernetes/base/ingress.yaml` with your actual domain name (replace `nextcloud.example.com`)
4. Access Nextcloud at https://your-domain.com

## Configuration

### Terraform Variables

Key variables in `terraform/variables.tf`:

- `resource_group_name`: Azure resource group name
- `location`: Azure region (e.g., westeurope, eastus)
- `prefix`: Prefix for resource names
- `node_count`: Initial number of AKS nodes
- `vm_size`: VM size for AKS nodes
- `mysql_admin_username`: MariaDB admin username
- `mysql_database_name`: Database name for Nextcloud

### Kubernetes Configuration

Key configurations in `kubernetes/base/configmap.yaml`:

- `NEXTCLOUD_TRUSTED_DOMAINS`: Domains allowed to access Nextcloud
- `PHP_MEMORY_LIMIT`: PHP memory limit
- `PHP_UPLOAD_LIMIT`: Maximum file upload size
- `REDIS_HOST`: Redis hostname for caching

## Scaling

### Horizontal Pod Autoscaling

To enable HPA for Nextcloud:

```bash
kubectl autoscale deployment nextcloud \
  --cpu-percent=70 \
  --min=2 \
  --max=10 \
  -n nextcloud
```

### AKS Node Autoscaling

The AKS cluster is configured with autoscaling enabled. Adjust `min_node_count` and `max_node_count` in Terraform variables.

## Monitoring

Consider installing:

- **Prometheus & Grafana**: For metrics and monitoring
- **Azure Monitor**: For AKS and resource monitoring
- **Log Analytics**: For centralized logging

## Backup and Disaster Recovery

1. **Database Backups**: Azure MariaDB Server provides automated backups
2. **File Backups**: Use Azure Storage snapshots or backup solutions
3. **Kubernetes Resources**: Store manifests in version control (this repository)

## Security Considerations

1. **Secrets Management**: 
   - Use Azure Key Vault for production secrets
   - Consider External Secrets Operator or Sealed Secrets
   
2. **Network Security**:
   - Configure Network Security Groups (NSGs)
   - Use Azure Private Link for MariaDB
   - Enable Pod Security Standards

3. **TLS/SSL**:
   - Use cert-manager with Let's Encrypt for automatic certificate management
   - Configure HTTPS-only access

4. **Database Security**:
   - Use strong passwords (auto-generated in Terraform)
   - Restrict firewall rules
   - Enable SSL connections

## Troubleshooting

### Terraform deployment errors

Note: This deployment now uses MariaDB which has better availability across Azure regions including westeurope.

### Check pod status
```bash
kubectl get pods -n nextcloud
kubectl describe pod <pod-name> -n nextcloud
kubectl logs <pod-name> -n nextcloud
```

### Check persistent volumes
```bash
kubectl get pv,pvc -n nextcloud
```

### Database connection issues
```bash
# Test from a debug pod
kubectl run -it --rm debug --image=mysql:14 --restart=Never -- psql -h <mysql-fqdn> -U nextcloudadmin -d nextcloud
```

## Cleanup

To destroy all resources:

```bash
# Delete Kubernetes resources
kubectl delete namespace nextcloud

# Destroy Terraform infrastructure
cd terraform
terraform destroy
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

MIT License - See LICENSE file for details

## References

- [Nextcloud Documentation](https://docs.nextcloud.com/)
- [Azure AKS Documentation](https://docs.microsoft.com/en-us/azure/aks/)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Kubernetes Documentation](https://kubernetes.io/docs/home/)