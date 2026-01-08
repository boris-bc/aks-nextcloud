# Examples and Use Cases

## Example 1: Basic Deployment with LoadBalancer

This is the default setup included in this repository.

**Use Case**: Quick deployment for testing or internal use

**Steps**:
1. Update secrets in `k8s/base/secrets.yaml`
2. Run `./deploy.sh`
3. Access via LoadBalancer IP

**Access**: `http://<EXTERNAL-IP>`

## Example 2: Production Deployment with Ingress and SSL

**Use Case**: Production deployment with custom domain and HTTPS

### Prerequisites
```bash
# Install NGINX Ingress Controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.9.0/deploy/static/provider/cloud/deploy.yaml

# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
```

### Steps

1. **Update secrets**:
```bash
nano k8s/base/secrets.yaml
# Set strong passwords
```

2. **Configure domain in ConfigMap**:
```yaml
# k8s/base/configmap.yaml
data:
  NEXTCLOUD_TRUSTED_DOMAINS: "nextcloud.yourdomain.com"
```

3. **Update cert-issuer email**:
```bash
nano k8s/base/cert-issuer.yaml
# Change email to your actual email
```

4. **Apply cert-issuer**:
```bash
kubectl apply -f k8s/base/cert-issuer.yaml
```

5. **Update Ingress with your domain**:
```yaml
# k8s/base/nextcloud-ingress.yaml
spec:
  tls:
  - hosts:
    - nextcloud.yourdomain.com  # Your domain
    secretName: nextcloud-tls
  rules:
  - host: nextcloud.yourdomain.com  # Your domain
```

6. **Deploy**:
```bash
./deploy.sh
kubectl apply -f k8s/base/nextcloud-ingress.yaml
```

7. **Configure DNS**:
```bash
# Get Ingress IP
kubectl get svc -n ingress-nginx

# Point your DNS A record to the Ingress IP
# nextcloud.yourdomain.com -> <INGRESS-IP>
```

**Access**: `https://nextcloud.yourdomain.com`

## Example 3: High Availability Setup with Multiple Replicas

**Use Case**: Production setup with redundancy

### Requirements
- Change storage from Azure Disk to Azure Files (supports ReadWriteMany)

### Steps

1. **Create Azure Files StorageClass**:
```yaml
# k8s/base/azurefile-storageclass.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: azurefile-premium
provisioner: file.csi.azure.com
parameters:
  skuName: Premium_LRS
allowVolumeExpansion: true
mountOptions:
  - dir_mode=0777
  - file_mode=0777
  - uid=33
  - gid=33
  - mfsymlinks
  - cache=strict
```

2. **Update Nextcloud PVC to use Azure Files**:
```yaml
# k8s/base/nextcloud-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nextcloud-pvc
  namespace: nextcloud
spec:
  accessModes:
    - ReadWriteMany  # Changed from ReadWriteOnce
  storageClassName: azurefile-premium  # Changed
  resources:
    requests:
      storage: 100Gi
```

3. **Deploy**:
```bash
kubectl apply -f k8s/base/azurefile-storageclass.yaml
./deploy.sh
```

4. **Scale to multiple replicas**:
```bash
kubectl scale deployment nextcloud -n nextcloud --replicas=3
```

## Example 4: Development Setup with Port Forwarding

**Use Case**: Local development and testing without external exposure

### Steps

1. **Deploy without LoadBalancer**:
```bash
# Skip the service creation or change type to ClusterIP
kubectl apply -f k8s/base/namespace.yaml
kubectl apply -f k8s/base/secrets.yaml
kubectl apply -f k8s/base/configmap.yaml
kubectl apply -f k8s/base/postgres-pvc.yaml
kubectl apply -f k8s/base/nextcloud-pvc.yaml
kubectl apply -f k8s/base/postgres-deployment.yaml
kubectl apply -f k8s/base/redis-deployment.yaml
kubectl apply -f k8s/base/nextcloud-deployment.yaml
```

2. **Create ClusterIP service** (modify nextcloud-service.yaml):
```yaml
apiVersion: v1
kind: Service
metadata:
  name: nextcloud-service
  namespace: nextcloud
spec:
  selector:
    app: nextcloud
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
  type: ClusterIP  # Changed from LoadBalancer
```

3. **Port forward**:
```bash
kubectl port-forward -n nextcloud svc/nextcloud-service 8080:80
```

**Access**: `http://localhost:8080`

## Example 5: Nextcloud with External Azure Database

**Use Case**: Use Azure Database for PostgreSQL instead of in-cluster database

### Prerequisites
- Azure Database for PostgreSQL created
- Database credentials
- Firewall rules configured for AKS

### Steps

1. **Update ConfigMap**:
```yaml
# k8s/base/configmap.yaml
data:
  POSTGRES_HOST: "your-server.postgres.database.azure.com"
  POSTGRES_DB: "nextcloud"
```

2. **Update Secrets**:
```yaml
# k8s/base/secrets.yaml
stringData:
  postgres-password: "your-azure-db-password"
```

3. **Skip PostgreSQL deployment**:
```bash
# Deploy everything except postgres
kubectl apply -f k8s/base/namespace.yaml
kubectl apply -f k8s/base/secrets.yaml
kubectl apply -f k8s/base/configmap.yaml
kubectl apply -f k8s/base/nextcloud-pvc.yaml
kubectl apply -f k8s/base/redis-deployment.yaml
kubectl apply -f k8s/base/nextcloud-deployment.yaml
kubectl apply -f k8s/base/nextcloud-service.yaml
```

## Example 6: Backup and Restore Workflow

### Backup

1. **Create backup script**:
```bash
#!/bin/bash
DATE=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="./backups/$DATE"

mkdir -p $BACKUP_DIR

# Backup database
echo "Backing up database..."
kubectl exec -n nextcloud deployment/postgres -- \
  pg_dump -U nextcloud nextcloud > $BACKUP_DIR/database.sql

# Backup Nextcloud config
echo "Backing up config..."
POD=$(kubectl get pod -n nextcloud -l app=nextcloud -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n nextcloud $POD -- tar czf /tmp/config.tar.gz /var/www/html/config
kubectl cp nextcloud/$POD:/tmp/config.tar.gz $BACKUP_DIR/config.tar.gz

# Backup Nextcloud data (optional, can be large)
echo "Backing up data..."
kubectl exec -n nextcloud $POD -- tar czf /tmp/data.tar.gz /var/www/html/data
kubectl cp nextcloud/$POD:/tmp/data.tar.gz $BACKUP_DIR/data.tar.gz

echo "Backup complete: $BACKUP_DIR"
```

### Restore

1. **Create restore script**:
```bash
#!/bin/bash
BACKUP_DIR=$1

if [ -z "$BACKUP_DIR" ]; then
  echo "Usage: $0 <backup-directory>"
  exit 1
fi

# Restore database
echo "Restoring database..."
POD=$(kubectl get pod -n nextcloud -l app=postgres -o jsonpath='{.items[0].metadata.name}')
kubectl cp $BACKUP_DIR/database.sql nextcloud/$POD:/tmp/
kubectl exec -n nextcloud $POD -- psql -U nextcloud nextcloud < /tmp/database.sql

# Restore config
echo "Restoring config..."
POD=$(kubectl get pod -n nextcloud -l app=nextcloud -o jsonpath='{.items[0].metadata.name}')
kubectl cp $BACKUP_DIR/config.tar.gz nextcloud/$POD:/tmp/
kubectl exec -n nextcloud $POD -- tar xzf /tmp/config.tar.gz -C /

# Restore data
echo "Restoring data..."
kubectl cp $BACKUP_DIR/data.tar.gz nextcloud/$POD:/tmp/
kubectl exec -n nextcloud $POD -- tar xzf /tmp/data.tar.gz -C /

# Fix permissions
kubectl exec -n nextcloud $POD -- chown -R www-data:www-data /var/www/html

# Restart
kubectl rollout restart deployment/nextcloud -n nextcloud

echo "Restore complete!"
```

## Example 7: Monitoring with Prometheus and Grafana

### Install Prometheus Stack

```bash
# Add helm repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace
```

### Access Grafana

```bash
# Port forward
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Default credentials: admin/prom-operator
```

### Monitor Nextcloud
- Import Kubernetes dashboards in Grafana
- Monitor pod resources, storage usage, and network traffic

## Example 8: Automated Backups with CronJob

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: nextcloud-backup
  namespace: nextcloud
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: postgres:15-alpine
            command:
            - /bin/sh
            - -c
            - |
              pg_dump -h postgres-service -U nextcloud nextcloud > /backup/nextcloud-$(date +%Y%m%d).sql
            env:
            - name: PGPASSWORD
              valueFrom:
                secretKeyRef:
                  name: nextcloud-secrets
                  key: postgres-password
            volumeMounts:
            - name: backup-storage
              mountPath: /backup
          restartPolicy: OnFailure
          volumes:
          - name: backup-storage
            persistentVolumeClaim:
              claimName: backup-pvc
```

## Customization Tips

### Custom PHP Configuration

Create a ConfigMap with custom PHP settings:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: php-config
  namespace: nextcloud
data:
  upload.ini: |
    upload_max_filesize = 10G
    post_max_size = 10G
    max_execution_time = 3600
    memory_limit = 512M
```

Mount in deployment:
```yaml
volumeMounts:
- name: php-config
  mountPath: /usr/local/etc/php/conf.d/upload.ini
  subPath: upload.ini
volumes:
- name: php-config
  configMap:
    name: php-config
```

### Custom Apps

Install apps during deployment:
```yaml
lifecycle:
  postStart:
    exec:
      command:
      - /bin/sh
      - -c
      - |
        php occ app:install calendar
        php occ app:install contacts
        php occ app:install tasks
```
