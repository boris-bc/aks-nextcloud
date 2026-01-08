#!/bin/bash

# Nextcloud AKS Validation Script
# This script validates the Nextcloud deployment

set -e

echo "=========================================="
echo "Nextcloud AKS Validation Script"
echo "=========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if kubectl is installed
echo -n "Checking kubectl installation... "
if command -v kubectl &> /dev/null; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
    echo "ERROR: kubectl is not installed"
    exit 1
fi

# Check if kubectl can connect to cluster
echo -n "Checking cluster connection... "
if kubectl cluster-info &> /dev/null; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
    echo "ERROR: Cannot connect to Kubernetes cluster"
    exit 1
fi

# Check if namespace exists
echo -n "Checking nextcloud namespace... "
if kubectl get namespace nextcloud &> /dev/null; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${YELLOW}!${NC} Namespace not found (not deployed yet)"
    exit 0
fi

echo ""
echo "Checking Resources..."
echo "--------------------"

# Check secrets
echo -n "Secrets... "
if kubectl get secret -n nextcloud nextcloud-secrets &> /dev/null; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
fi

# Check configmap
echo -n "ConfigMap... "
if kubectl get configmap -n nextcloud nextcloud-config &> /dev/null; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
fi

# Check PVCs
echo -n "PostgreSQL PVC... "
if kubectl get pvc -n nextcloud postgres-pvc &> /dev/null; then
    STATUS=$(kubectl get pvc -n nextcloud postgres-pvc -o jsonpath='{.status.phase}')
    if [ "$STATUS" == "Bound" ]; then
        echo -e "${GREEN}✓ (Bound)${NC}"
    else
        echo -e "${YELLOW}! ($STATUS)${NC}"
    fi
else
    echo -e "${RED}✗${NC}"
fi

echo -n "Nextcloud PVC... "
if kubectl get pvc -n nextcloud nextcloud-pvc &> /dev/null; then
    STATUS=$(kubectl get pvc -n nextcloud nextcloud-pvc -o jsonpath='{.status.phase}')
    if [ "$STATUS" == "Bound" ]; then
        echo -e "${GREEN}✓ (Bound)${NC}"
    else
        echo -e "${YELLOW}! ($STATUS)${NC}"
    fi
else
    echo -e "${RED}✗${NC}"
fi

echo ""
echo "Checking Deployments..."
echo "----------------------"

# Check PostgreSQL
echo -n "PostgreSQL deployment... "
if kubectl get deployment -n nextcloud postgres &> /dev/null; then
    READY=$(kubectl get deployment -n nextcloud postgres -o jsonpath='{.status.readyReplicas}' || echo "0")
    READY=${READY:-0}
    DESIRED=$(kubectl get deployment -n nextcloud postgres -o jsonpath='{.spec.replicas}')
    if [ "$READY" == "$DESIRED" ]; then
        echo -e "${GREEN}✓ ($READY/$DESIRED ready)${NC}"
    else
        echo -e "${YELLOW}! ($READY/$DESIRED ready)${NC}"
    fi
else
    echo -e "${RED}✗${NC}"
fi

# Check Redis
echo -n "Redis deployment... "
if kubectl get deployment -n nextcloud redis &> /dev/null; then
    READY=$(kubectl get deployment -n nextcloud redis -o jsonpath='{.status.readyReplicas}' || echo "0")
    READY=${READY:-0}
    DESIRED=$(kubectl get deployment -n nextcloud redis -o jsonpath='{.spec.replicas}')
    if [ "$READY" == "$DESIRED" ]; then
        echo -e "${GREEN}✓ ($READY/$DESIRED ready)${NC}"
    else
        echo -e "${YELLOW}! ($READY/$DESIRED ready)${NC}"
    fi
else
    echo -e "${RED}✗${NC}"
fi

# Check Nextcloud
echo -n "Nextcloud deployment... "
if kubectl get deployment -n nextcloud nextcloud &> /dev/null; then
    READY=$(kubectl get deployment -n nextcloud nextcloud -o jsonpath='{.status.readyReplicas}' || echo "0")
    READY=${READY:-0}
    DESIRED=$(kubectl get deployment -n nextcloud nextcloud -o jsonpath='{.spec.replicas}')
    if [ "$READY" == "$DESIRED" ]; then
        echo -e "${GREEN}✓ ($READY/$DESIRED ready)${NC}"
    else
        echo -e "${YELLOW}! ($READY/$DESIRED ready)${NC}"
    fi
else
    echo -e "${RED}✗${NC}"
fi

echo ""
echo "Checking Pods..."
echo "---------------"

kubectl get pods -n nextcloud

echo ""
echo "Checking Services..."
echo "-------------------"

# Check service
if kubectl get svc -n nextcloud nextcloud-service &> /dev/null; then
    EXTERNAL_IP=$(kubectl get svc -n nextcloud nextcloud-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    if [ -n "$EXTERNAL_IP" ]; then
        echo -e "LoadBalancer service: ${GREEN}✓${NC}"
        echo -e "External IP: ${GREEN}$EXTERNAL_IP${NC}"
        echo ""
        echo "Access Nextcloud at: http://$EXTERNAL_IP"
    else
        echo -e "LoadBalancer service: ${YELLOW}! (IP pending)${NC}"
        echo "Waiting for external IP assignment..."
    fi
else
    echo -e "LoadBalancer service: ${RED}✗${NC}"
fi

echo ""
echo "Checking Ingress..."
echo "------------------"

if kubectl get ingress -n nextcloud nextcloud-ingress &> /dev/null; then
    echo -e "Ingress: ${GREEN}✓${NC}"
    kubectl get ingress -n nextcloud nextcloud-ingress
else
    echo -e "Ingress: ${YELLOW}! (not deployed)${NC}"
fi

echo ""
echo "Resource Usage..."
echo "----------------"

if kubectl top nodes &> /dev/null; then
    kubectl top nodes
    echo ""
    kubectl top pods -n nextcloud
else
    echo -e "${YELLOW}Metrics server not available${NC}"
fi

echo ""
echo "=========================================="
echo "Validation Complete!"
echo "=========================================="
echo ""

# Summary
POSTGRES_READY=$(kubectl get deployment -n nextcloud postgres -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
REDIS_READY=$(kubectl get deployment -n nextcloud redis -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
NEXTCLOUD_READY=$(kubectl get deployment -n nextcloud nextcloud -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")

if [ "$POSTGRES_READY" == "1" ] && [ "$REDIS_READY" == "1" ] && [ "$NEXTCLOUD_READY" == "1" ]; then
    echo -e "${GREEN}✓ All services are running!${NC}"
    echo ""
    echo "Next steps:"
    echo "  - Access Nextcloud via the external IP shown above"
    echo "  - For production setup, configure Ingress with SSL/TLS"
    echo "  - Set up regular backups"
else
    echo -e "${YELLOW}! Some services are not ready yet${NC}"
    echo ""
    echo "Troubleshooting:"
    echo "  - Check pod logs: kubectl logs -n nextcloud <pod-name>"
    echo "  - Check events: kubectl get events -n nextcloud --sort-by='.lastTimestamp'"
    echo "  - Check pod details: kubectl describe pod -n nextcloud <pod-name>"
fi

echo ""
