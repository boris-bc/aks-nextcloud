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
  --from-literal=db-host="$(terraform output -raw mysql_fqdn)" \
  --from-literal=db-name="nextcloud" \
  --from-literal=db-username="nextcloudadmin" \
  --from-literal=db-password="$(terraform output -raw mysql_admin_password)"
```

### Step 5: Deploy Application

```bash
cd ../kubernetes/overlays/prod
kubectl apply -k .
```

## Troubleshooting

Note: This deployment now uses MySQL which has better availability in westeurope and other regions.

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

## Troubleshooting

### Nextcloud Pods Crashing

If Nextcloud pods are in CrashLoopBackOff state:

1. **Check if MySQL is running:**
```bash
kubectl get pods -n nextcloud -l app=mysql
kubectl get statefulset -n nextcloud
```

2. **If MySQL pod doesn't exist, deploy it:**
```bash
kubectl apply -f kubernetes/base/mysql-statefulset.yaml
```

3. **Wait for MySQL to be ready:**
```bash
kubectl wait --for=condition=ready pod -l app=mysql -n nextcloud --timeout=300s
```

4. **Check MySQL logs:**
```bash
kubectl logs -n nextcloud -l app=mysql
```

5. **Restart Nextcloud after MySQL is ready:**
```bash
kubectl rollout restart deployment/nextcloud -n nextcloud
```

### Nextcloud Pods Not Becoming Ready

If Nextcloud pods show as Running but READY is 0/1 for extended periods:

1. **Check Nextcloud logs for initialization progress:**
```bash
kubectl logs -n nextcloud -l app=nextcloud --tail=100
```

2. **Nextcloud first-time initialization can take 5-10 minutes.** The startup probe allows up to 10 minutes (60 failures × 10 sec period = 600 sec).

3. **If you see "connection refused" errors, the database might not be ready yet.**

4. **Check pod events for health probe failures:**
```bash
kubectl get events -n nextcloud --field-selector involvedObject.name=<pod-name>
```

5. **If initialization is stuck, check database connectivity:**
```bash
kubectl exec -it -n nextcloud deployment/nextcloud -- mysql -h mysql -u nextcloud -p
# Enter the password from the secret
```

### Database Connection Issues

If Nextcloud can't connect to MySQL:

1. **Verify secrets are created (not using placeholders):**
```bash
kubectl get secret nextcloud-db -n nextcloud -o jsonpath='{.data.db-password}' | base64 -d
# Should show a random password, not "REPLACE_WITH_MYSQL_PASSWORD"
```

2. **Verify MySQL is accessible:**
```bash
kubectl get svc mysql -n nextcloud
# Should show ClusterIP: None (headless service)
```

3. **Test database connectivity from a debug pod:**
```bash
kubectl run -it --rm debug --image=mysql:8.0 --restart=Never -n nextcloud -- mysql -h mysql -u nextcloud -p
```

3. **Check MySQL service:**
```bash
kubectl get svc mysql -n nextcloud
```

### MySQL StatefulSet Issues

If MySQL pod won't start:

1. **Check persistent volume claim:**
```bash
kubectl get pvc -n nextcloud
```

2. **Check MySQL logs:**
```bash
kubectl logs -n nextcloud mysql-0
```

3. **Describe the MySQL pod:**
```bash
kubectl describe pod mysql-0 -n nextcloud
```

### Pods Stuck in Pending State

If pods remain in Pending state:

1. **Check node availability:**
```bash
kubectl get nodes
```

2. **Describe the pending pod:**
```bash
kubectl describe pod <pod-name> -n nextcloud
```

3. **Check for resource constraints or PVC binding issues**

### Re-deployment

If you need to completely redeploy:

1. **Delete all Kubernetes resources:**
```bash
kubectl delete namespace nextcloud
```

2. **Recreate namespace:**
```bash
kubectl create namespace nextcloud
```

3. **Run deployment script again:**
```bash
cd scripts
./deploy.sh
```
