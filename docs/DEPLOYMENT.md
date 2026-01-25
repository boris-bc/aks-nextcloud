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

## Scaling Nextcloud

**Important:** The deployment starts with **1 replica** to avoid concurrent database initialization conflicts.

### After Initial Deployment

Once Nextcloud is fully initialized and running (all pods show READY 1/1), you can scale to multiple replicas:

```bash
# Scale to 2 replicas (default for base)
kubectl scale deployment nextcloud -n nextcloud --replicas=2

# Or scale to 3 replicas (recommended for prod)
kubectl scale deployment nextcloud -n nextcloud --replicas=3
```

### Why Start with 1 Replica?

Nextcloud's initialization process:
- Creates database schema and tables on first run
- Uses file locking to prevent concurrent initialization
- Multiple pods starting simultaneously causes "flock: Permission denied" errors
- After initialization, Nextcloud supports multiple replicas without issues

### Verifying Initialization

Check if Nextcloud has completed initialization:

```bash
# Check pod status - should show READY 1/1
kubectl get pods -n nextcloud -l app=nextcloud

# Check logs - should show "Nextcloud is already installed"
kubectl logs -n nextcloud -l app=nextcloud --tail=20

# Once you see "Nextcloud is already installed", it's safe to scale up
kubectl scale deployment nextcloud -n nextcloud --replicas=2
```

## Cleanup

To remove all deployed resources:

```bash
cd scripts
./cleanup.sh
```

Or manually:

```bash
# Delete Kubernetes resources
kubectl delete namespace nextcloud

# Delete Azure infrastructure
cd terraform
terraform destroy
```

## Troubleshooting

Note: This deployment uses containerized MySQL which works in all Azure regions without subscription restrictions.

### Common Issues

#### Concurrent Initialization Conflicts

If you see errors like "flock: Permission denied" or "Another process is initializing Nextcloud":

**Cause:** Multiple Nextcloud pods trying to initialize the database simultaneously.

**Solution:**
1. **Delete all Nextcloud pods to stop conflicting initialization:**
```bash
kubectl delete pods -n nextcloud -l app=nextcloud
```

2. **Ensure only 1 replica is configured during first deployment:**
```bash
kubectl scale deployment nextcloud -n nextcloud --replicas=1
```

3. **Wait for initialization to complete** (5-10 minutes):
```bash
kubectl logs -f -n nextcloud -l app=nextcloud
# Wait until you see "Nextcloud is already installed"
```

4. **Once initialized, scale to desired replicas:**
```bash
kubectl scale deployment nextcloud -n nextcloud --replicas=2
```

**Prevention:** The base deployment now starts with 1 replica by default to avoid this issue.

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

2. **Nextcloud first-time initialization can take 10-20 minutes.** The startup probe allows up to 20 minutes (120 failures × 10 sec period = 1200 sec).

3. **If logs show "Initializing nextcloud..." with no further output:**
   - Initialization is running silently in the background
   - Database schema creation can take 10-20 minutes on first run
   - Wait and continue monitoring logs with `kubectl logs -f -n nextcloud -l app=nextcloud`

4. **Check pod events and restart count:**
```bash
kubectl get pods -n nextcloud -l app=nextcloud  # Check RESTARTS column
kubectl get events -n nextcloud --field-selector involvedObject.name=<pod-name> --sort-by='.lastTimestamp'
```

5. **If pod is restarting before initialization completes:**
   - Events will show "Container nextcloud failed startup probe"
   - Temporarily disable startup probe to let initialization finish:
   ```bash
   # Note: This assumes nextcloud is the first container (index 0) in the pod spec
   kubectl patch deployment nextcloud -n nextcloud --type=json -p='[{"op": "remove", "path": "/spec/template/spec/containers/0/startupProbe"}]'
   ```
   - Wait 15-20 minutes for initialization
   - Re-enable probe: `kubectl apply -f kubernetes/base/nextcloud-deployment.yaml`

6. **Verify Apache is running inside the container:**
```bash
# Get the pod name first
POD_NAME=$(kubectl get pods -n nextcloud -l app=nextcloud -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n nextcloud $POD_NAME -- ps aux | grep apache
```

7. **If initialization is stuck, check database connectivity from a test pod:**
```bash
kubectl run -it --rm debug --image=mysql:8.0 --restart=Never -n nextcloud -- mysql -h mysql -u nextcloud -p
# Enter password from: kubectl get secret nextcloud-db -n nextcloud -o jsonpath='{.data.db-password}' | base64 -d
```

**Note:** The `mysql` command is not available in Nextcloud pods. Use a separate MySQL debug pod as shown above.

### Database Connection Issues

If Nextcloud can't connect to MySQL:

1. **Verify secrets are created (not using placeholders):**
```bash
kubectl get secret nextcloud-db -n nextcloud -o jsonpath='{.data.db-password}' | base64 -d
# Should show a random password, not "REPLACE_WITH_MYSQL_PASSWORD"
```

2. **Verify MySQL services are running:**
```bash
kubectl get svc -n nextcloud
# Should show two MySQL services:
# - mysql: ClusterIP with an IP address (for client connections)
# - mysql-headless: ClusterIP None (for StatefulSet pod management)
```

3. **Test database connectivity from a debug pod:**
```bash
kubectl run -it --rm debug --image=mysql:8.0 --restart=Never -n nextcloud -- mysql -h mysql -u nextcloud -p
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
