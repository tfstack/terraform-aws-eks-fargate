# CloudMap Integration for Single Cluster

This module provides CloudMap integration for service discovery within a single EKS Fargate cluster.

## Overview

The CloudMap integration enables automatic service discovery for applications running in your EKS Fargate cluster. This is **different** from the AWS Cloud Map MCS Controller, which is designed for multicluster scenarios.

## Key Features

- ✅ **Single-cluster service discovery**
- ✅ **Automatic service registration**
- ✅ **DNS-based service resolution**
- ✅ **Health checking support**
- ✅ **IAM roles and RBAC configured**
- ✅ **Fargate-optimized**

## Quick Start

1. **Enable CloudMap in your configuration**:

   ```hcl
   module "eks_fargate" {
     source = "path/to/terraform-aws-eks-fargate"

     # Basic cluster config...
     cluster_name = "my-cluster"
     vpc_id       = "vpc-123456"

     # Enable CloudMap integration
     enable_cloudmap              = true
     enable_cloudmap_controller   = true
     cloudmap_namespace_name      = "myapp.local"
     cloudmap_namespace_description = "Service discovery for my application"

     # Optional: Enable load balancer integration
     enable_cloudmap_load_balancer_integration = false
   }
   ```

2. **Deploy your services with CloudMap annotations**:

   ```hcl
   workloads = [
     {
       name      = "api-service"
       namespace = "default"
       replicas  = 2

       containers = [{
         name  = "api"
         image = "my-api:latest"
         ports = [{
           containerPort = 8080
         }]
         env = [
           {
             name  = "DATABASE_URL"
             value = "http://database-service.myapp.local:5432"
           }
         ]
       }]
     }
   ]
   ```

## How It Works

### Architecture

```
┌─────────────────────────────────────────────┐
│               EKS Fargate Cluster           │
│                                             │
│  ┌─────────────┐    ┌─────────────┐       │
│  │   Service A │    │   Service B │       │
│  │             │    │             │       │
│  │ Fargate Pod │    │ Fargate Pod │       │
│  └─────────────┘    └─────────────┘       │
│           │                   │            │
│           └───────────────────┘            │
│                     │                      │
│        CloudMap Service Discovery          │
│                     │                      │
│  ┌─────────────────────────────────────┐   │
│  │      myapp.local namespace         │   │
│  │                                     │   │
│  │  • service-a.myapp.local           │   │
│  │  • service-b.myapp.local           │   │
│  └─────────────────────────────────────┘   │
│                                             │
│  ┌─────────────────────────────────────┐   │
│  │       CloudMap Controller          │   │
│  │                                     │   │
│  │  • Watches Kubernetes Services     │   │
│  │  • Registers endpoints in CloudMap │   │
│  │  • Manages health checks           │   │
│  └─────────────────────────────────────┘   │
└─────────────────────────────────────────────┘
```

### Components

1. **CloudMap Namespace**: Private DNS namespace for your services
2. **CloudMap Controller**: Kubernetes controller that manages service registration
3. **IAM Roles**: Proper permissions for CloudMap API access
4. **Service Accounts**: Kubernetes RBAC configuration

## Configuration Options

### Required Variables

```hcl
enable_cloudmap              = true
cloudmap_namespace_name      = "myapp.local"    # Your DNS namespace
enable_cloudmap_controller   = true
```

### Optional Variables

```hcl
cloudmap_namespace_description               = "Service discovery namespace"
enable_cloudmap_load_balancer_integration   = false  # AWS LB Controller integration
cloudmap_create_ecs_service_discovery_role   = false  # For ECS integration
```

### CloudMap Services Configuration

```hcl
cloudmap_services = {
  "api-service" = {
    name                                  = "api-service"
    description                           = "Main API service"
    dns_record_type                       = "A"
    routing_policy                        = "MULTIVALUE"
    health_check_custom_config            = true
    custom_health_check_failure_threshold = 1
  }
}
```

## Service Discovery Usage

### DNS Resolution

Services can discover each other using DNS names:

```bash
# From within a pod:
curl http://api-service.myapp.local:8080/health
nslookup database-service.myapp.local
```

### Environment Variables

Configure your applications with service URLs:

```yaml
env:
  - name: API_URL
    value: "http://api-service.myapp.local:8080"
  - name: DATABASE_URL
    value: "http://database.myapp.local:5432"
```

## Monitoring and Troubleshooting

### Check Controller Status

```bash
# View controller logs
kubectl logs -n cloudmap-system -l app.kubernetes.io/name=cloudmap-controller

# Check controller pod status
kubectl get pods -n cloudmap-system

# View service account
kubectl describe serviceaccount cloudmap-controller -n cloudmap-system
```

### Verify CloudMap Resources

```bash
# List CloudMap namespaces
aws servicediscovery list-namespaces

# List services in namespace
aws servicediscovery list-services --filters Name=NAMESPACE_ID,Values=<namespace-id>

# View service instances
aws servicediscovery list-instances --service-id <service-id>
```

### Test Service Discovery

```bash
# Run a test pod
kubectl run test-pod --image=busybox --rm -it -- sh

# Test DNS resolution
nslookup api-service.myapp.local

# Test connectivity
wget -qO- http://api-service.myapp.local:8080/health
```

## Differences from Multicluster MCS

| Feature | Single-Cluster CloudMap | Multicluster MCS |
|---------|------------------------|-------------------|
| **Use Case** | Service discovery within one cluster | Service discovery across clusters |
| **Complexity** | Simple setup | Complex multicluster setup |
| **CRDs** | None required | ServiceImport/ServiceExport |
| **CoreDNS** | Standard CoreDNS | Requires multicluster plugin |
| **Blog Post** | This implementation | AWS MCS Controller blog |

## Common Issues

### Service Not Resolving

1. Check if CloudMap controller is running
2. Verify IAM permissions
3. Ensure namespace exists in CloudMap

### Permission Denied

1. Check IRSA (IAM Role for Service Account) configuration
2. Verify CloudMap policy permissions
3. Check OIDC provider is enabled

### Pods Can't Connect

1. Verify Fargate profile covers the namespace
2. Check security group rules
3. Test DNS resolution first

## Best Practices

1. **Use meaningful DNS names**: `api-service.myapp.local`
2. **Enable health checks**: Monitor service health
3. **Use environment variables**: Don't hardcode service URLs
4. **Monitor CloudMap costs**: CloudMap charges per service/query
5. **Plan your namespace**: Use descriptive names like `prod.myapp.local`

## Security Considerations

- CloudMap controller runs with minimal required permissions
- Uses IAM Roles for Service Accounts (IRSA)
- Private DNS namespace doesn't expose services externally
- Health checks can be configured for additional security

## Cost Optimization

- CloudMap charges per namespace and service
- Consider using fewer services for cost efficiency
- Use health checks judiciously
- Monitor CloudMap usage in AWS Cost Explorer
