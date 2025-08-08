# EKS Fargate with MCS Controller Service Discovery

This example demonstrates how to deploy an EKS Fargate cluster with the official AWS MCS (Multicluster Service) controller for service discovery. The setup includes:

- **EKS Fargate Cluster**: Serverless Kubernetes cluster using AWS Fargate
- **MCS Controller**: Official AWS Multicluster Service controller for service discovery
- **Microservices Demo**: Two sample services (user-service and order-service) with service discovery

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    EKS Fargate Cluster                     │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐    ┌─────────────────┐              │
│  │   user-service  │    │  order-service  │              │
│  │   (2 replicas)  │    │   (2 replicas)  │              │
│  └─────────────────┘    └─────────────────┘              │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    MCS Controller                         │
├─────────────────────────────────────────────────────────────┤
│  • ServiceExport/ServiceImport CRDs                       │
│  • Automatic CloudMap integration                         │
│  • Multicluster service discovery                         │
│  • Cross-cluster service communication                    │
└─────────────────────────────────────────────────────────────┘
```

## Features

- **MCS Controller**: Official AWS Multicluster Service controller for service discovery
- **ServiceExport/ServiceImport**: Kubernetes CRDs for multicluster service discovery
- **Automatic CloudMap Integration**: Services automatically registered in CloudMap
- **Cross-cluster Communication**: Support for multicluster service discovery
- **Fargate Profiles**: Dedicated Fargate profile for microservices namespace

## Prerequisites

- Terraform >= 1.0
- AWS CLI configured
- Appropriate AWS permissions for EKS, CloudMap, and VPC resources

## Usage

1. **Initialize Terraform**:

   ```bash
   terraform init
   ```

2. **Review the plan**:

   ```bash
   terraform plan
   ```

3. **Deploy the infrastructure**:

   ```bash
   terraform apply
   ```

4. **Configure kubectl**:

   ```bash
   aws eks update-kubeconfig --region ap-southeast-2 --name <cluster-name>
   ```

## Service Discovery

### MCS Controller Configuration

The example installs the AWS MCS controller which provides:

- **ServiceExport CRD**: Export services to other clusters
- **ServiceImport CRD**: Import services from other clusters
- **Multicluster Discovery**: Cross-cluster service discovery
- **Automatic CloudMap Registration**: Automatic service registration in CloudMap

### Service Communication

Services can communicate using DNS names:

```bash
# From within the cluster
curl http://user-service.microservices.local
curl http://order-service.microservices.local
```

### Service Annotations

The services are configured with annotations for external DNS integration:

```yaml
annotations:
  service.beta.kubernetes.io/aws-load-balancer-type: external
  external-dns.alpha.kubernetes.io/hostname: user-service.microservices.local
```

## Outputs

After deployment, you'll get:

- **Cluster Information**: Name, endpoint, and configuration
- **Fargate Profiles**: Names and selectors
- **CloudMap Resources**: Namespace ID, name, and service details
- **Service ARNs**: For ECS integration

## Cleanup

To destroy the infrastructure:

```bash
terraform destroy
```

## Cost Considerations

- **EKS Fargate**: Pay per pod for compute resources
- **CloudMap**: Charges per namespace and service
- **VPC**: NAT Gateway and data transfer costs
- **CloudWatch**: Log storage and ingestion costs

## Security

- **Private Subnets**: All EKS resources run in private subnets
- **IAM Roles**: Least privilege access for service discovery
- **Network Policies**: VPC isolation for service communication
- **Encryption**: EKS secrets encryption (configurable)

## Troubleshooting

### Service Discovery Issues

1. **Check CloudMap namespace**:

   ```bash
   aws servicediscovery list-namespaces
   ```

2. **Verify services**:

   ```bash
   aws servicediscovery list-services
   ```

3. **Test DNS resolution**:

   ```bash
   nslookup user-service.microservices.local
   ```

### Pod Issues

1. **Check pod status**:

   ```bash
   kubectl get pods -n microservices
   ```

2. **View pod logs**:

   ```bash
   kubectl logs -n microservices deployment/user-service
   ```

3. **Check service endpoints**:

   ```bash
   kubectl get endpoints -n microservices
   ```

## Next Steps

- **Add External DNS**: Configure external-dns for automatic DNS record management
- **Implement Health Checks**: Add proper health check endpoints to your services
- **Scale Services**: Adjust replica counts based on load
- **Add Monitoring**: Integrate with CloudWatch and Prometheus
- **Security Hardening**: Implement network policies and pod security standards
