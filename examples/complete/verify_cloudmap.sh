#!/bin/bash
set -e
export AWS_DEFAULT_REGION=ap-southeast-2

echo "=== CloudMap Integration Verification ==="
echo ""

echo "1. Checking AWS connectivity..."
aws sts get-caller-identity

echo ""
echo "2. Checking EKS clusters..."
aws eks list-clusters

echo ""
echo "3. Checking CloudMap namespaces..."
aws servicediscovery list-namespaces

echo ""
echo "4. If cluster exists, checking kubectl access..."
CLUSTER_NAME=$(aws eks list-clusters --query 'clusters[0]' --output text 2>/dev/null || echo "")
if [ ! -z "$CLUSTER_NAME" ]; then
    echo "Found cluster: $CLUSTER_NAME"
    aws eks update-kubeconfig --name "$CLUSTER_NAME" --region ap-southeast-2
    
    echo ""
    echo "5. Checking CloudMap controller..."
    kubectl get pods -n cloudmap-system 2>/dev/null || echo "CloudMap controller not found"
    
    echo ""
    echo "6. Checking services with CloudMap annotation..."
    kubectl get services --all-namespaces -o json | jq -r '.items[] | select(.metadata.annotations["service.cloudmap/register"] == "true") | "\(.metadata.namespace)/\(.metadata.name): \(.spec.clusterIP)"' 2>/dev/null || echo "No annotated services found"
    
    echo ""
    echo "7. Checking CloudMap services..."
    aws servicediscovery list-namespaces --query 'Namespaces[?Name==`demo.internal`].Id' --output text | while read nsid; do
        if [ ! -z "$nsid" ]; then
            echo "Found CloudMap namespace ID: $nsid"
            aws servicediscovery list-services --filters Name=NAMESPACE_ID,Values=$nsid
        fi
    done
else
    echo "No EKS cluster found"
fi
