#!/bin/bash
set -e
export AWS_DEFAULT_REGION=ap-southeast-2

echo "=== Post-Deployment CloudMap Verification ==="
echo ""

echo "1. Getting cluster name from terraform output..."
CLUSTER_NAME=$(terraform output -raw cluster_name 2>/dev/null || echo "")
echo "Cluster name: $CLUSTER_NAME"

echo ""
echo "2. Updating kubeconfig..."
if [ ! -z "$CLUSTER_NAME" ]; then
    aws eks update-kubeconfig --name "$CLUSTER_NAME" --region ap-southeast-2
else
    echo "No cluster found in terraform output"
    exit 1
fi

echo ""
echo "3. Checking CloudMap controller deployment..."
kubectl get pods -n cloudmap-system
kubectl get cronjobs -n cloudmap-system

echo ""
echo "4. Checking services with CloudMap annotation..."
kubectl get services --all-namespaces -o json | jq -r '.items[] | select(.metadata.annotations["service.cloudmap/register"] == "true") | "\(.metadata.namespace)/\(.metadata.name): \(.spec.clusterIP)"'

echo ""
echo "5. Checking CloudMap namespace..."
NAMESPACE_ID=$(aws servicediscovery list-namespaces --query 'Namespaces[?Name==`demo.internal`].Id' --output text)
if [ ! -z "$NAMESPACE_ID" ]; then
    echo "Found CloudMap namespace: $NAMESPACE_ID"
    
    echo ""
    echo "6. Checking CloudMap services..."
    aws servicediscovery list-services --filters Name=NAMESPACE_ID,Values=$NAMESPACE_ID
    
    echo ""
    echo "7. Checking service instances..."
    aws servicediscovery list-services --filters Name=NAMESPACE_ID,Values=$NAMESPACE_ID --query 'Services[*].Id' --output text | while read svc_id; do
        if [ ! -z "$svc_id" ]; then
            echo "Service ID: $svc_id"
            aws servicediscovery list-instances --service-id $svc_id
        fi
    done
else
    echo "CloudMap namespace 'demo.internal' not found"
fi

echo ""
echo "8. Testing DNS resolution..."
kubectl run test-dns --image=busybox --rm -i --restart=Never -- nslookup logger-test.demo.internal || echo "DNS test failed"

echo ""
echo "=== Verification Complete ==="
