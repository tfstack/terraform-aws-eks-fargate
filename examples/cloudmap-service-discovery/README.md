# CloudMap Service Discovery Example

This example demonstrates how to set up AWS CloudMap service discovery for a single EKS Fargate cluster.

## Overview

This example creates:

- EKS Fargate cluster with CloudMap integration
- CloudMap private DNS namespace (`microservices.local`)
- Sample microservices that can discover each other
- CloudMap controller for automatic service registration

## Architecture

```
┌─────────────────────────────────────────────┐
│               EKS Fargate Cluster           │
│                                             │
│  ┌─────────────┐    ┌─────────────┐       │
│  │ user-service│    │order-service│       │
│  │             │    │             │       │
│  │ Port: 80    │    │ Port: 80    │       │
│  └─────────────┘    └─────────────┘       │
│           │                   │            │
│           └───────────────────┘            │
│                     │                      │
│              CloudMap Service Discovery    │
│                     │                      │
│  ┌─────────────────────────────────────┐   │
│  │     microservices.local namespace   │   │
│  │                                     │   │
│  │  • user-service.microservices.local │   │
│  │  • order-service.microservices.local│   │
│  └─────────────────────────────────────┘   │
└─────────────────────────────────────────────┘
```

## What This Example Does

1. **Creates CloudMap Resources**: Sets up a private DNS namespace for service discovery
2. **Deploys CloudMap Controller**: Kubernetes controller that manages service registration
3. **Configures RBAC**: Proper IAM roles and permissions for CloudMap access
4. **Deploys Sample Services**: Two microservices that can discover each other
5. **Automatic Registration**: Services are automatically registered in CloudMap

## Key Differences from Multicluster MCS

This is **NOT** the multicluster MCS Controller from the AWS blog post. This is single-cluster CloudMap integration that:

- Works within a single EKS cluster
- Uses CloudMap for internal service discovery
- Doesn't require CoreDNS multicluster plugin
- Much simpler setup for single-cluster use cases
- No ServiceImport/ServiceExport CRDs needed

## Usage

1. **Deploy the infrastructure**:

   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

2. **Test service discovery**:

   ```bash
   # Get cluster credentials
   aws eks update-kubeconfig --region ap-southeast-2 --name <cluster-name>

   # Check pods are running
   kubectl get pods -n microservices

   # Test service discovery from one pod
   kubectl exec -it <user-service-pod> -n microservices -- bash
   nslookup user-service.microservices.local
   nslookup order-service.microservices.local

   # Test HTTP connectivity
   curl http://order-service.microservices.local
   ```

3. **View CloudMap resources**:

   ```bash
   # List CloudMap namespaces
   aws servicediscovery list-namespaces

   # List services in the namespace
   aws servicediscovery list-services --namespace-id <namespace-id>
   ```

## Service Discovery Features

- **DNS-based discovery**: Services resolve to IPs via DNS
- **Health checking**: CloudMap can track service health
- **Load balancing**: Multiple instances automatically load balanced
- **Automatic registration**: No manual service registration needed

## Environment Variables

Your workloads can use these environment variables for service discovery:

```yaml
env:
  - name: SERVICE_NAME
    value: "user-service"
  - name: CLOUDMAP_NAMESPACE
    value: "microservices.local"
  - name: USER_SERVICE_URL
    value: "http://user-service.microservices.local"
```

## Cleanup

```bash
terraform destroy
```

## Troubleshooting

1. **Services not resolving**: Check CloudMap controller logs

   ```bash
   kubectl logs -n cloudmap-system -l app.kubernetes.io/name=cloudmap-controller
   ```

2. **Permission issues**: Verify IAM role has CloudMap permissions

   ```bash
   kubectl describe serviceaccount cloudmap-controller -n cloudmap-system
   ```

3. **DNS resolution**: Test from within a pod

   ```bash
   kubectl run test-pod --image=busybox --rm -it -- nslookup user-service.microservices.local
   ```
