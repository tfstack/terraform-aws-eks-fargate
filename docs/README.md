# AWS Cloud Map MCS Controller - Implementation for EKS Fargate

This repository contains the **implementation requirements** to add AWS Cloud Map multi-cluster service discovery support to an existing EKS Fargate module.

## What This Implements

This configuration demonstrates the **complete setup** needed to enable multi-cluster service discovery using AWS Cloud Map MCS Controller on EKS. The components below are what you need to implement in your existing EKS Fargate module.

## Required Components to Implement

### 1. Infrastructure Requirements

**VPC Configuration:**
- Public and private subnets across multiple AZs
- NAT Gateway for private subnet internet access
- Proper route tables and security groups
- VPC peering (for multi-cluster scenarios)

**IAM Roles:**
- EKS cluster role with proper permissions
- Service account role for MCS Controller with `AWSCloudMapFullAccess`
- Node group roles (if using EC2 nodes alongside Fargate)

### 2. Kubernetes Resources

**Namespaces:**
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: cloud-map-mcs-system
---
apiVersion: v1
kind: Namespace
metadata:
  name: demo
```

**CoreDNS Configuration:**
- Custom CoreDNS deployment with multicluster plugin
- ConfigMap for DNS configuration
- ClusterRole for CoreDNS permissions

**MCS Controller Installation:**
```bash
kubectl apply -k "github.com/aws/aws-cloud-map-mcs-controller-for-k8s/config/controller_install_release"
```

### 3. ClusterSet Configuration

**Cluster Identity Setup:**
```yaml
apiVersion: about.k8s.io/v1alpha1
kind: ClusterProperty
metadata:
  name: cluster.clusterset.k8s.io
spec:
  value: "your-cluster-id"
---
apiVersion: about.k8s.io/v1alpha1
kind: ClusterProperty
metadata:
  name: clusterset.k8s.io
spec:
  value: "your-clusterset-id"
```

### 4. Service Export/Import Example

**Export a Service:**
```yaml
apiVersion: multicluster.x-k8s.io/v1alpha1
kind: ServiceExport
metadata:
  namespace: demo
  name: nginx-hello
```

**Import a Service (automatic):**
```yaml
apiVersion: multicluster.x-k8s.io/v1alpha1
kind: ServiceImport
metadata:
  namespace: demo
  name: nginx-hello
spec:
  type: ClusterSetIP
  ports:
  - port: 80
    protocol: TCP
```

## Implementation Steps for Your EKS Fargate Module

### Step 1: Add IAM Service Account
```hcl
# Add to your existing EKS module
resource "aws_iam_role" "mcs_controller" {
  name = "${var.cluster_name}-mcs-controller-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")}"
        }
        Condition = {
          StringEquals = {
            "${replace(aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:cloud-map-mcs-system:cloud-map-mcs-controller-manager"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "mcs_controller_cloudmap" {
  policy_arn = "arn:aws:iam::aws:policy/AWSCloudMapFullAccess"
  role       = aws_iam_role.mcs_controller.name
}
```

### Step 2: Add Kubernetes Resources
```hcl
# Add to your existing Kubernetes resources
resource "kubernetes_namespace" "cloud_map_mcs_system" {
  metadata {
    name = "cloud-map-mcs-system"
  }
}

resource "kubernetes_service_account" "mcs_controller" {
  metadata {
    name      = "cloud-map-mcs-controller-manager"
    namespace = "cloud-map-mcs-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.mcs_controller.arn
    }
  }
}

# CoreDNS resources
resource "kubectl_manifest" "coredns_clusterrole" {
  yaml_body = file("${path.module}/coredns-clusterrole.yaml")
}

resource "kubectl_manifest" "coredns_configmap" {
  yaml_body = file("${path.module}/coredns-configmap.yaml")
}

resource "kubectl_manifest" "coredns_deployment" {
  yaml_body = file("${path.module}/coredns-deployment.yaml")
}
```

### Step 3: Add MCS Controller Installation
```hcl
# Install MCS Controller
resource "kubectl_manifest" "mcs_controller" {
  yaml_body = file("${path.module}/mcsapi-clusterproperty.yaml")
  depends_on = [
    kubernetes_namespace.cloud_map_mcs_system,
    kubernetes_service_account.mcs_controller
  ]
}
```

## Example Usage

### Single Cluster Setup
```hcl
module "eks_with_cloudmap" {
  source = "your-module-path"
  
  cluster_name = "my-cluster"
  aws_region   = "us-west-2"
  
  # Enable Cloud Map support
  enable_cloud_map = true
  cluster_set_id   = "my-clusterset"
  cluster_id       = "my-cluster-1"
}
```

### Multi-Cluster Setup
```hcl
# Cluster 1
module "eks_cluster_1" {
  source = "your-module-path"
  
  cluster_name = "cluster-1"
  aws_region   = "us-west-2"
  
  enable_cloud_map = true
  cluster_set_id   = "my-clusterset"
  cluster_id       = "cluster-1"
}

# Cluster 2
module "eks_cluster_2" {
  source = "your-module-path"
  
  cluster_name = "cluster-2"
  aws_region   = "us-west-2"
  
  enable_cloud_map = true
  cluster_set_id   = "my-clusterset"  # Same ClusterSet
  cluster_id       = "cluster-2"      # Different Cluster ID
}
```

## Testing the Implementation

### 1. Deploy Test Services
```bash
# Create demo namespace
kubectl create namespace demo

# Deploy nginx service
kubectl apply -f samples/nginx-deployment.yaml
kubectl apply -f samples/nginx-service.yaml

# Export the service
kubectl apply -f samples/nginx-serviceexport.yaml
```

### 2. Test Cross-Cluster Discovery
```bash
# Deploy client pod
kubectl apply -f samples/client-hello.yaml

# Test DNS resolution
kubectl exec -it client-hello -n demo -- nslookup nginx-hello.demo.svc.clusterset.local

# Test HTTP requests
kubectl exec -it client-hello -n demo -- curl nginx-hello.demo.svc.clusterset.local
```

## Key Files to Include in Your Module

1. **`coredns-clusterrole.yaml`** - CoreDNS RBAC permissions
2. **`coredns-configmap.yaml`** - CoreDNS configuration with multicluster plugin
3. **`coredns-deployment.yaml`** - CoreDNS deployment
4. **`mcsapi-clusterproperty.yaml`** - ClusterSet configuration
5. **`nginx-deployment.yaml`** - Example application deployment
6. **`nginx-service.yaml`** - Example service
7. **`nginx-serviceexport.yaml`** - Example service export
8. **`client-hello.yaml`** - Example client pod for testing

## Variables to Add to Your Module

```hcl
variable "enable_cloud_map" {
  description = "Enable AWS Cloud Map MCS Controller"
  type        = bool
  default     = false
}

variable "cluster_set_id" {
  description = "ClusterSet ID for MCS Controller"
  type        = string
  default     = "default-clusterset"
}

variable "cluster_id" {
  description = "Cluster ID for MCS Controller"
  type        = string
  default     = ""
}
```

## Important Notes

1. **Network Connectivity**: Ensure proper VPC peering between clusters for multi-cluster scenarios
2. **IAM Permissions**: The MCS Controller needs `AWSCloudMapFullAccess` policy
3. **DNS Resolution**: CoreDNS must be configured with the multicluster plugin
4. **Service Discovery**: Services use `*.svc.clusterset.local` domain for cross-cluster discovery
5. **Fargate Compatibility**: This implementation works with EKS on Fargate, but requires proper networking setup

## Troubleshooting

### Common Issues
- **IAM Role Issues**: Verify service account has proper IAM role attached
- **DNS Resolution**: Check CoreDNS logs and configuration
- **Service Export**: Ensure ServiceExport objects are in correct namespace
- **Network Connectivity**: Verify VPC peering and security groups for multi-cluster

### Useful Commands
```bash
# Check MCS Controller status
kubectl get pods -n cloud-map-mcs-system

# View controller logs
kubectl logs -n cloud-map-mcs-system deployment/cloud-map-mcs-controller-manager

# Check ServiceExport status
kubectl get serviceexports -A

# Check ServiceImport status
kubectl get serviceimports -A
```

## References

- [AWS Cloud Map MCS Controller](https://github.com/aws/aws-cloud-map-mcs-controller-for-k8s)
- [Kubernetes Multi-Cluster Services API](https://github.com/kubernetes-sigs/mcs-api)
- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [AWS Cloud Map Documentation](https://docs.aws.amazon.com/cloud-map/)
