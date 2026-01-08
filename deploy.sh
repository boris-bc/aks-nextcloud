#!/bin/bash

# Nextcloud AKS Deployment Script
# This script deploys Nextcloud to an Azure Kubernetes Service cluster

set -e

echo "=========================================="
echo "Nextcloud AKS Deployment Script"
echo "=========================================="
echo ""

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo "ERROR: kubectl is not installed. Please install kubectl first."
    exit 1
fi

# Check if kubectl can connect to cluster
if ! kubectl cluster-info &> /dev/null; then
    echo "ERROR: Cannot connect to Kubernetes cluster. Please configure kubectl first."
    exit 1
fi

echo "✓ kubectl is configured and connected to cluster"
echo ""

# Check if secrets have been customized
if grep -q "CHANGE_ME" k8s/base/secrets.yaml; then
    echo "WARNING: You need to customize the secrets in k8s/base/secrets.yaml"
    echo "Please update the following values:"
    echo "  - postgres-password"
    echo "  - nextcloud-admin-password"
    echo "  - redis-password"
    echo ""
    read -p "Have you updated the secrets? (yes/no): " answer
    if [ "$answer" != "yes" ]; then
        echo "Please update the secrets before deploying."
        exit 1
    fi
fi

echo "Deploying Nextcloud to Kubernetes..."
echo ""

# Create namespace
echo "Creating namespace..."
kubectl apply -f k8s/base/namespace.yaml

# Create secrets and configmap
echo "Creating secrets and configmap..."
kubectl apply -f k8s/base/secrets.yaml
kubectl apply -f k8s/base/configmap.yaml

# Create PVCs
echo "Creating persistent volume claims..."
kubectl apply -f k8s/base/postgres-pvc.yaml
kubectl apply -f k8s/base/nextcloud-pvc.yaml

# Deploy PostgreSQL
echo "Deploying PostgreSQL..."
kubectl apply -f k8s/base/postgres-deployment.yaml

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL to be ready..."
kubectl wait --for=condition=ready pod -l app=postgres -n nextcloud --timeout=300s

# Deploy Redis
echo "Deploying Redis..."
kubectl apply -f k8s/base/redis-deployment.yaml

# Wait for Redis to be ready
echo "Waiting for Redis to be ready..."
kubectl wait --for=condition=ready pod -l app=redis -n nextcloud --timeout=300s

# Deploy Nextcloud
echo "Deploying Nextcloud..."
kubectl apply -f k8s/base/nextcloud-deployment.yaml
kubectl apply -f k8s/base/nextcloud-service.yaml

# Wait for Nextcloud to be ready
echo "Waiting for Nextcloud to be ready (this may take several minutes)..."
kubectl wait --for=condition=ready pod -l app=nextcloud -n nextcloud --timeout=600s

echo ""
echo "=========================================="
echo "Deployment Complete!"
echo "=========================================="
echo ""

# Get service information
echo "Service Information:"
kubectl get svc -n nextcloud nextcloud-service

echo ""
echo "To access Nextcloud:"
echo "1. Get the external IP: kubectl get svc -n nextcloud nextcloud-service"
echo "2. Access Nextcloud at: http://<EXTERNAL-IP>"
echo ""
echo "To deploy the ingress (optional):"
echo "  kubectl apply -f k8s/base/nextcloud-ingress.yaml"
echo ""
echo "To check pod status:"
echo "  kubectl get pods -n nextcloud"
echo ""
echo "To view logs:"
echo "  kubectl logs -n nextcloud -l app=nextcloud"
echo ""
