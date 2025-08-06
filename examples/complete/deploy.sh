#!/bin/bash
set -e

echo "=== Deploying EKS Fargate with CloudMap Integration ==="
echo ""

echo "1. Validating Terraform configuration..."
terraform validate

echo ""
echo "2. Planning deployment..."
terraform plan -out=tfplan

echo ""
echo "3. Applying infrastructure..."
terraform apply tfplan

echo ""
echo "4. Getting outputs..."
terraform output

echo ""
echo "Deployment completed! Now let's verify CloudMap integration..."
