#!/bin/bash
# Deploy script for Nextcloud on AKS
set -e

echo "================================"
echo "Nextcloud AKS Deployment Script"
echo "================================"

# Check prerequisites
command -v az >/dev/null 2>&1 || { echo "Azure CLI is required but not installed. Aborting." >&2; exit 1; }
command -v terraform >/dev/null 2>&1 || { echo "Terraform is required but not installed. Aborting." >&2; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "kubectl is required but not installed. Aborting." >&2; exit 1; }

# Step 1: Deploy infrastructure with Terraform
echo ""
echo "Step 1: Deploying Azure infrastructure..."
cd terraform

if [ ! -f "terraform.tfvars" ]; then
    echo "Error: terraform.tfvars not found. Please create it from terraform.tfvars.example"
    exit 1
fi

terraform init
terraform plan -out=tfplan
terraform apply tfplan

# Extract outputs
RESOURCE_GROUP=$(terraform output -raw resource_group_name)
AKS_CLUSTER=$(terraform output -raw aks_cluster_name)
POSTGRES_FQDN=$(terraform output -raw postgres_fqdn)
POSTGRES_PASSWORD=$(terraform output -raw postgres_admin_password)
STORAGE_ACCOUNT_NAME=$(terraform output -raw storage_account_name)
STORAGE_ACCOUNT_KEY=$(terraform output -raw storage_account_key)

echo "Infrastructure deployed successfully!"

# Step 2: Configure kubectl
echo ""
echo "Step 2: Configuring kubectl..."
az aks get-credentials --resource-group "$RESOURCE_GROUP" --name "$AKS_CLUSTER" --overwrite-existing

# Step 3: Create namespace
echo ""
echo "Step 3: Creating namespace..."
kubectl apply -f ../kubernetes/base/namespace.yaml

# Step 4: Create secrets
echo ""
echo "Step 4: Creating secrets..."
kubectl create secret generic nextcloud-db \
  --from-literal=db-host="$POSTGRES_FQDN" \
  --from-literal=db-name="nextcloud" \
  --from-literal=db-username="nextcloudadmin" \
  --from-literal=db-password="$POSTGRES_PASSWORD" \
  --namespace=nextcloud --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic azure-storage \
  --from-literal=azurestorageaccountname="$STORAGE_ACCOUNT_NAME" \
  --from-literal=azurestorageaccountkey="$STORAGE_ACCOUNT_KEY" \
  --namespace=nextcloud --dry-run=client -o yaml | kubectl apply -f -

# Generate a random admin password
ADMIN_PASSWORD=$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-24)

kubectl create secret generic nextcloud-admin \
  --from-literal=admin-username="admin" \
  --from-literal=admin-password="$ADMIN_PASSWORD" \
  --namespace=nextcloud --dry-run=client -o yaml | kubectl apply -f -

# Save credentials securely
CREDS_DIR="$HOME/.nextcloud"
mkdir -p "$CREDS_DIR"
chmod 700 "$CREDS_DIR"
echo "Admin password: $ADMIN_PASSWORD" > "$CREDS_DIR/credentials.txt"
chmod 600 "$CREDS_DIR/credentials.txt"

echo "Admin credentials saved securely to: $CREDS_DIR/credentials.txt"

echo "Secrets created successfully!"

# Step 5: Deploy Kubernetes resources
echo ""
echo "Step 5: Deploying Nextcloud to Kubernetes..."
cd ../kubernetes/base
kubectl apply -f configmap.yaml
kubectl apply -f pvc.yaml
kubectl apply -f redis.yaml
kubectl apply -f nextcloud-deployment.yaml
kubectl apply -f nextcloud-service.yaml

echo ""
echo "================================"
echo "Deployment completed!"
echo "================================"
echo ""
echo "Waiting for LoadBalancer IP..."
kubectl wait --for=condition=ready pod -l app=nextcloud -n nextcloud --timeout=300s || true

EXTERNAL_IP=""
while [ -z "$EXTERNAL_IP" ]; do
    echo "Waiting for external IP..."
    EXTERNAL_IP=$(kubectl get svc nextcloud -n nextcloud -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
    [ -z "$EXTERNAL_IP" ] && sleep 10
done

echo ""
echo "Nextcloud is accessible at: http://$EXTERNAL_IP"
echo "Default admin credentials:"
echo "  Username: admin"
echo "  Password: See $HOME/.nextcloud/credentials.txt"
echo ""
echo "IMPORTANT: Save your admin password from $HOME/.nextcloud/credentials.txt"
echo ""
echo "To check status: kubectl get all -n nextcloud"
echo "To view logs: kubectl logs -f deployment/nextcloud -n nextcloud"
