# Getting Started - Nextcloud on AKS

This is a **5-minute quick start guide** to get Nextcloud running on Azure Kubernetes Service.

## Prerequisites Checklist

- [ ] Azure subscription
- [ ] Azure CLI installed ([install](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli))
- [ ] kubectl installed ([install](https://kubernetes.io/docs/tasks/tools/))
- [ ] 20-30 minutes for initial setup

## Step-by-Step Setup

### 1. Create AKS Cluster (5-10 minutes)

```bash
# Login to Azure
az login

# Set variables (customize these)
RESOURCE_GROUP="nextcloud-rg"
CLUSTER_NAME="nextcloud-aks"
LOCATION="eastus"

# Create resource group
az group create --name $RESOURCE_GROUP --location $LOCATION

# Create AKS cluster (takes 5-10 minutes)
az aks create \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --node-count 2 \
  --node-vm-size Standard_D2s_v3 \
  --enable-managed-identity \
  --generate-ssh-keys

# Get credentials
az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME

# Verify connection
kubectl get nodes
```

**Expected output**: You should see 2 nodes in Ready status.

### 2. Clone Repository

```bash
git clone https://github.com/boris-bc/aks-nextcloud.git
cd aks-nextcloud
```

### 3. Configure Secrets (IMPORTANT!)

Open `k8s/base/secrets.yaml` and replace the placeholder passwords:

```bash
nano k8s/base/secrets.yaml  # or use your preferred editor
```

Change these values:
- `CHANGE_ME_POSTGRES_PASSWORD` → Choose a strong password (e.g., `MyP0stgr3sP@ss`)
- `CHANGE_ME_ADMIN_PASSWORD` → Choose a strong admin password (e.g., `MyAdm1nP@ss`)
- `CHANGE_ME_REDIS_PASSWORD` → Choose a strong password (e.g., `MyR3d1sP@ss`)

**⚠️ Security Warning**: Never commit real passwords to git!

### 4. Deploy Nextcloud (5-10 minutes)

```bash
# Make the script executable (if not already)
chmod +x deploy.sh

# Run deployment
./deploy.sh
```

The script will:
1. ✓ Create namespace
2. ✓ Create secrets and config
3. ✓ Create storage volumes
4. ✓ Deploy PostgreSQL
5. ✓ Deploy Redis
6. ✓ Deploy Nextcloud
7. ✓ Create LoadBalancer service

**Expected output**: All pods should be running after 5-10 minutes.

### 5. Access Nextcloud

Get the external IP address:

```bash
kubectl get svc -n nextcloud nextcloud-service
```

Wait until you see an EXTERNAL-IP (not `<pending>`). This may take 2-3 minutes.

**Access Nextcloud**:
1. Copy the EXTERNAL-IP
2. Open your browser and go to: `http://<EXTERNAL-IP>`
3. Login with:
   - **Username**: `admin`
   - **Password**: The password you set in `secrets.yaml`

🎉 **Congratulations!** Nextcloud is now running on Azure!

## What's Next?

### Production Setup

For production use, you should:

1. **Set up a custom domain and HTTPS**:
   - See [README.md](README.md#using-ingress-with-ssltls) for Ingress setup
   - See [EXAMPLES.md](EXAMPLES.md#example-2-production-deployment-with-ingress-and-ssl) for complete example

2. **Configure backups**:
   - See [QUICKREF.md](QUICKREF.md#backup) for backup commands
   - See [EXAMPLES.md](EXAMPLES.md#example-6-backup-and-restore-workflow) for automated backups

3. **Monitor your deployment**:
   - Use `kubectl get pods -n nextcloud` to check status
   - See [QUICKREF.md](QUICKREF.md#monitoring) for monitoring commands

### Common Next Steps

```bash
# Check deployment status
kubectl get all -n nextcloud

# View logs
kubectl logs -n nextcloud -l app=nextcloud -f

# Scale up (requires Azure Files storage)
kubectl scale deployment nextcloud -n nextcloud --replicas=3

# Enable maintenance mode
kubectl exec -n nextcloud deployment/nextcloud -- php occ maintenance:mode --on
```

## Troubleshooting

### Pods not starting?

```bash
# Check pod status
kubectl get pods -n nextcloud

# View pod details
kubectl describe pod -n nextcloud <pod-name>

# View logs
kubectl logs -n nextcloud <pod-name>
```

### Can't access Nextcloud?

1. Ensure LoadBalancer has external IP:
   ```bash
   kubectl get svc -n nextcloud nextcloud-service
   ```

2. Check if pods are running:
   ```bash
   kubectl get pods -n nextcloud
   ```

3. View Nextcloud logs:
   ```bash
   kubectl logs -n nextcloud -l app=nextcloud
   ```

### "Trusted domain" error?

This is normal when accessing via IP. To fix:
```bash
# Get the pod name
POD=$(kubectl get pod -n nextcloud -l app=nextcloud -o jsonpath='{.items[0].metadata.name}')

# Add your IP as trusted domain
kubectl exec -n nextcloud $POD -- \
  php occ config:system:set trusted_domains 1 --value='<YOUR-IP>'
```

## Cleanup

To remove everything:

```bash
# Delete Nextcloud
./cleanup.sh

# Delete AKS cluster (optional)
az aks delete --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME
az group delete --name $RESOURCE_GROUP
```

## Need Help?

- 📖 [Complete Documentation](README.md)
- 🔧 [Quick Reference](QUICKREF.md)
- 💡 [Examples](EXAMPLES.md)
- ☁️ [Azure Setup Guide](AZURE_SETUP.md)

## Cost Estimate

Approximate Azure costs (as of 2024):
- **2 x Standard_D2s_v3 nodes**: ~$140/month
- **LoadBalancer**: ~$20/month
- **Managed Disks (60GB)**: ~$5/month
- **Total**: ~$165/month

💰 **Cost Saving Tip**: Stop the cluster when not in use:
```bash
az aks stop --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME
```

## Architecture Summary

```
Internet → LoadBalancer → Nextcloud Pod → PostgreSQL Pod
                              ↓
                          Redis Pod
                              ↓
                        Azure Managed Disks
```

**Components**:
- **Nextcloud**: Web application (latest stable version)
- **PostgreSQL**: Database server (version 15)
- **Redis**: Cache and session storage (version 7)
- **Azure Managed Disks**: Persistent storage
- **LoadBalancer**: Azure Load Balancer for external access

## Resources

- [Nextcloud Documentation](https://docs.nextcloud.com/)
- [Azure Kubernetes Service Docs](https://docs.microsoft.com/en-us/azure/aks/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)

---

**Ready to deploy?** Start with step 1 above! 🚀
