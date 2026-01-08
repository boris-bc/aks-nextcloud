# Quick Reference Guide

## Essential Commands

### Deployment
```bash
# Deploy everything
./deploy.sh

# Deploy manually step by step
kubectl apply -f k8s/base/namespace.yaml
kubectl apply -f k8s/base/secrets.yaml
kubectl apply -f k8s/base/configmap.yaml
kubectl apply -f k8s/base/postgres-pvc.yaml
kubectl apply -f k8s/base/nextcloud-pvc.yaml
kubectl apply -f k8s/base/postgres-deployment.yaml
kubectl apply -f k8s/base/redis-deployment.yaml
kubectl apply -f k8s/base/nextcloud-deployment.yaml
kubectl apply -f k8s/base/nextcloud-service.yaml
```

### Monitoring
```bash
# Check all resources
kubectl get all -n nextcloud

# Check pods
kubectl get pods -n nextcloud

# Watch pods
kubectl get pods -n nextcloud -w

# Check services
kubectl get svc -n nextcloud

# Check PVCs
kubectl get pvc -n nextcloud

# Describe pod
kubectl describe pod -n nextcloud <pod-name>
```

### Logs
```bash
# View Nextcloud logs
kubectl logs -n nextcloud -l app=nextcloud -f

# View PostgreSQL logs
kubectl logs -n nextcloud -l app=postgres -f

# View Redis logs
kubectl logs -n nextcloud -l app=redis -f

# View previous container logs (if crashed)
kubectl logs -n nextcloud <pod-name> --previous
```

### Access Nextcloud
```bash
# Get external IP
kubectl get svc -n nextcloud nextcloud-service

# Port forward (for testing)
kubectl port-forward -n nextcloud svc/nextcloud-service 8080:80

# Access via browser: http://localhost:8080
```

### Execute Commands in Pods
```bash
# Access Nextcloud shell
kubectl exec -it -n nextcloud deployment/nextcloud -- bash

# Access PostgreSQL
kubectl exec -it -n nextcloud deployment/postgres -- psql -U nextcloud

# Access Redis CLI
kubectl exec -it -n nextcloud deployment/redis -- redis-cli -a <password>
```

### Scaling
```bash
# Scale Nextcloud (requires shared storage)
kubectl scale deployment nextcloud -n nextcloud --replicas=3

# Check replica status
kubectl get deployment -n nextcloud
```

### Updates
```bash
# Update Nextcloud image
kubectl set image deployment/nextcloud -n nextcloud nextcloud=nextcloud:29-apache

# Rolling restart
kubectl rollout restart deployment/nextcloud -n nextcloud

# Check rollout status
kubectl rollout status deployment/nextcloud -n nextcloud

# Rollback
kubectl rollout undo deployment/nextcloud -n nextcloud
```

### Configuration Changes
```bash
# Edit ConfigMap
kubectl edit configmap -n nextcloud nextcloud-config

# Edit Secrets
kubectl edit secret -n nextcloud nextcloud-secrets

# Apply changes after editing files
kubectl apply -f k8s/base/configmap.yaml
kubectl apply -f k8s/base/secrets.yaml

# Restart to apply changes
kubectl rollout restart deployment/nextcloud -n nextcloud
```

### Backup
```bash
# Backup database
kubectl exec -n nextcloud deployment/postgres -- \
  pg_dump -U nextcloud nextcloud > nextcloud-db-$(date +%Y%m%d).sql

# Backup Nextcloud files
kubectl exec -n nextcloud deployment/nextcloud -- \
  tar czf /tmp/nextcloud-data.tar.gz /var/www/html

kubectl cp nextcloud/<pod-name>:/tmp/nextcloud-data.tar.gz \
  ./nextcloud-data-$(date +%Y%m%d).tar.gz
```

### Restore
```bash
# Restore database
kubectl cp nextcloud-db-backup.sql nextcloud/<postgres-pod>:/tmp/
kubectl exec -n nextcloud deployment/postgres -- \
  psql -U nextcloud nextcloud < /tmp/nextcloud-db-backup.sql
```

### Troubleshooting
```bash
# Check events
kubectl get events -n nextcloud --sort-by='.lastTimestamp'

# Check pod status
kubectl get pods -n nextcloud -o wide

# Check resource usage
kubectl top pods -n nextcloud
kubectl top nodes

# Check persistent volumes
kubectl get pv
kubectl describe pv <pv-name>

# Force delete stuck pod
kubectl delete pod -n nextcloud <pod-name> --grace-period=0 --force
```

### Cleanup
```bash
# Delete all Nextcloud resources (keep data)
./cleanup.sh

# Delete including data
kubectl delete namespace nextcloud
```

### Ingress
```bash
# Deploy ingress
kubectl apply -f k8s/base/nextcloud-ingress.yaml

# Check ingress
kubectl get ingress -n nextcloud

# Describe ingress
kubectl describe ingress -n nextcloud nextcloud-ingress

# Check cert-manager certificates
kubectl get certificate -n nextcloud
kubectl describe certificate -n nextcloud nextcloud-tls
```

### Debugging
```bash
# Run temporary pod for debugging
kubectl run -it --rm debug --image=busybox --restart=Never -n nextcloud -- sh

# Test DNS resolution
kubectl run -it --rm debug --image=busybox --restart=Never -n nextcloud -- \
  nslookup postgres-service.nextcloud.svc.cluster.local

# Test connectivity
kubectl run -it --rm debug --image=busybox --restart=Never -n nextcloud -- \
  wget -O- http://nextcloud-service.nextcloud.svc.cluster.local

# Check node logs (requires node access)
kubectl get nodes
kubectl describe node <node-name>
```

### Useful One-Liners
```bash
# Get all pod names
kubectl get pods -n nextcloud -o jsonpath='{.items[*].metadata.name}'

# Get external IP immediately
kubectl get svc -n nextcloud nextcloud-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

# Check if all pods are ready
kubectl get pods -n nextcloud -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.phase}{"\n"}{end}'

# Get pod restart counts
kubectl get pods -n nextcloud -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.containerStatuses[0].restartCount}{"\n"}{end}'

# Delete all failed pods
kubectl delete pods -n nextcloud --field-selector status.phase=Failed
```

## Environment Variables Reference

### Nextcloud Container
- `POSTGRES_HOST` - PostgreSQL hostname
- `POSTGRES_DB` - Database name
- `POSTGRES_USER` - Database user
- `POSTGRES_PASSWORD` - Database password
- `REDIS_HOST` - Redis hostname
- `REDIS_HOST_PASSWORD` - Redis password
- `NEXTCLOUD_ADMIN_USER` - Admin username
- `NEXTCLOUD_ADMIN_PASSWORD` - Admin password
- `NEXTCLOUD_TRUSTED_DOMAINS` - Allowed domains
- `OVERWRITEPROTOCOL` - Force protocol (http/https)

### PostgreSQL Container
- `POSTGRES_DB` - Database name
- `POSTGRES_USER` - Database user
- `POSTGRES_PASSWORD` - Database password
- `PGDATA` - Data directory

### Redis Container
- `REDIS_PASSWORD` - Redis password (via command args)

## Common Issues and Solutions

### Issue: Pods stuck in Pending
**Solution**: Check PVC status and storage class availability
```bash
kubectl get pvc -n nextcloud
kubectl describe pvc -n nextcloud <pvc-name>
```

### Issue: Database connection failed
**Solution**: Verify PostgreSQL is ready and credentials are correct
```bash
kubectl logs -n nextcloud -l app=postgres
kubectl exec -n nextcloud deployment/postgres -- psql -U nextcloud -c '\l'
```

### Issue: Trusted domain error
**Solution**: Add your domain/IP to trusted domains
```bash
kubectl exec -n nextcloud deployment/nextcloud -- \
  php occ config:system:set trusted_domains 0 --value='your-domain.com'
```

### Issue: Permission denied on files
**Solution**: Fix permissions
```bash
kubectl exec -n nextcloud deployment/nextcloud -- \
  chown -R www-data:www-data /var/www/html
```

### Issue: Out of memory
**Solution**: Increase resource limits
```bash
kubectl edit deployment -n nextcloud nextcloud
# Increase memory limits in resources section
```
