#!/bin/bash
# Cleanup script for Nextcloud AKS deployment
set -e

echo "================================"
echo "Nextcloud AKS Cleanup Script"
echo "================================"

read -p "Are you sure you want to delete all resources? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Cleanup cancelled."
    exit 0
fi

# Delete Kubernetes resources
echo ""
echo "Deleting Kubernetes resources..."
kubectl delete namespace nextcloud --ignore-not-found=true

# Wait for namespace deletion
echo "Waiting for namespace deletion..."
kubectl wait --for=delete namespace/nextcloud --timeout=300s || true

# Destroy Terraform infrastructure
echo ""
echo "Destroying Azure infrastructure..."
cd terraform

if [ -f "terraform.tfstate" ]; then
    terraform destroy -auto-approve
else
    echo "No Terraform state found. Skipping infrastructure cleanup."
fi

echo ""
echo "================================"
echo "Cleanup completed!"
echo "================================"
