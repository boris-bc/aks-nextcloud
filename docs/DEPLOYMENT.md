# Deployment Guide

This guide provides step-by-step instructions for deploying Nextcloud on Azure Kubernetes Service.

## Prerequisites

Before starting, ensure you have:

1. **Azure Account** with an active subscription
2. **Azure CLI** installed and logged in (`az login`)
3. **Terraform** (>= 1.0) installed
4. **kubectl** (>= 1.24) installed
5. Appropriate Azure permissions to create resources

## Automated Deployment

The quickest way to deploy is using the provided script:

```bash
cd scripts
./deploy.sh
```

This script will:
- Deploy the Terraform infrastructure
- Configure kubectl
- Create all necessary secrets
- Deploy Nextcloud to Kubernetes
- Wait for the service to be ready
- Display the access URL

## Manual Deployment

For more control over the deployment process, follow these steps:

### Step 1: Configure Terraform

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your settings
```

### Step 2: Deploy Infrastructure

```bash
terraform init
terraform plan
terraform apply
```

### Step 3: Configure Kubernetes

```bash
az aks get-credentials --resource-group <rg-name> --name <aks-name>
kubectl get nodes
```

### Step 4: Create Secrets

```bash
kubectl create secret generic nextcloud-db --namespace=nextcloud \
  --from-literal=db-host="$(terraform output -raw mariadb_fqdn)" \
  --from-literal=db-name="nextcloud" \
  --from-literal=db-username="nextcloudadmin" \
  --from-literal=db-password="$(terraform output -raw mariadb_admin_password)"
```

### Step 5: Deploy Application

```bash
cd ../kubernetes/overlays/prod
kubectl apply -k .
```

## Troubleshooting

Note: This deployment now uses MariaDB which has better availability in westeurope and other regions.

### Pod Issues

Check pod logs:
```bash
kubectl logs -f deployment/nextcloud -n nextcloud
```

Check resource status:
```bash
kubectl get all -n nextcloud
```

## Cleanup

```bash
cd scripts
./cleanup.sh
```
