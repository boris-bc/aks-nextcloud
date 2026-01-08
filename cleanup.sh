#!/bin/bash

# Nextcloud AKS Cleanup Script
# This script removes all Nextcloud resources from the cluster

set -e

echo "=========================================="
echo "Nextcloud AKS Cleanup Script"
echo "=========================================="
echo ""

read -p "This will delete all Nextcloud resources. Are you sure? (yes/no): " answer
if [ "$answer" != "yes" ]; then
    echo "Cleanup cancelled."
    exit 0
fi

echo "Removing Nextcloud resources..."

# Remove ingress
kubectl delete -f k8s/base/nextcloud-ingress.yaml --ignore-not-found=true

# Remove services
kubectl delete -f k8s/base/nextcloud-service.yaml --ignore-not-found=true

# Remove deployments
kubectl delete -f k8s/base/nextcloud-deployment.yaml --ignore-not-found=true
kubectl delete -f k8s/base/redis-deployment.yaml --ignore-not-found=true
kubectl delete -f k8s/base/postgres-deployment.yaml --ignore-not-found=true

# Remove PVCs (this will delete data)
read -p "Delete persistent volumes (this will delete all data)? (yes/no): " delete_data
if [ "$delete_data" == "yes" ]; then
    kubectl delete -f k8s/base/nextcloud-pvc.yaml --ignore-not-found=true
    kubectl delete -f k8s/base/postgres-pvc.yaml --ignore-not-found=true
fi

# Remove configmap and secrets
kubectl delete -f k8s/base/configmap.yaml --ignore-not-found=true
kubectl delete -f k8s/base/secrets.yaml --ignore-not-found=true

# Remove namespace
kubectl delete -f k8s/base/namespace.yaml --ignore-not-found=true

echo ""
echo "Cleanup complete!"
