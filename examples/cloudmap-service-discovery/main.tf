############################################
# CloudMap Service Discovery Example
############################################

provider "aws" {
  region = "ap-southeast-2"
}

############################################
# Data Sources
############################################

data "http" "my_public_ip" {
  url = "https://checkip.amazonaws.com/"
}

############################################
# Random Suffix for Resource Names
############################################

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

############################################
# Local Variables
############################################

locals {
  azs                 = ["ap-southeast-2a", "ap-southeast-2b", "ap-southeast-2c"]
  name                = "cloudmap-demo"
  base_name           = local.suffix != "" ? "${local.name}-${local.suffix}" : local.name
  suffix              = random_string.suffix.result
  private_subnets     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  public_subnets      = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  region              = "ap-southeast-2"
  vpc_cidr            = "10.0.0.0/16"
  eks_cluster_version = "1.33"
  service_cidr        = "10.100.0.0/16"

  tags = {
    Environment = "dev"
    Project     = "cloudmap-demo"
  }
}

############################################
# VPC Configuration
############################################

module "vpc" {
  source = "cloudbuildlab/vpc/aws"

  vpc_name           = local.base_name
  vpc_cidr           = local.vpc_cidr
  availability_zones = local.azs

  public_subnet_cidrs  = local.public_subnets
  private_subnet_cidrs = local.private_subnets

  # Enable Internet Gateway & NAT Gateway
  create_igw       = true
  nat_gateway_type = "single"

  tags = local.tags

  enable_eks_tags  = true
  eks_cluster_name = local.base_name
}

############################################
# EKS Fargate with CloudMap Integration
############################################

module "eks_fargate" {
  source = "../.."

  vpc_id          = module.vpc.vpc_id
  cluster_name    = local.base_name
  cluster_version = local.eks_cluster_version
  tags            = local.tags

  cluster_vpc_config = {
    subnet_ids           = module.vpc.private_subnet_ids
    private_subnet_ids   = module.vpc.private_subnet_ids
    private_access_cidrs = module.vpc.private_subnet_cidrs
    public_access_cidrs  = ["0.0.0.0/0"]
    service_cidr         = local.service_cidr

    security_group_ids      = []
    endpoint_private_access = false
    endpoint_public_access  = true
  }

  cluster_enabled_log_types = ["api", "audit"]

  enable_cluster_encryption = false
  enable_oidc               = true
  eks_log_prevent_destroy   = false
  eks_log_retention_days    = 1

  enable_cloudwatch_observability = true

  namespaces = [
    {
      name = "microservices"
      labels = {
        "purpose" = "cloudmap-demo"
      }
    }
  ]

  fargate_profiles = [
    {
      name       = "microservices"
      subnet_ids = module.vpc.private_subnet_ids

      selectors = [
        {
          namespace = "microservices"
        }
      ]
    }
  ]

  enable_coredns_addon  = true
  coredns_addon_version = "latest"

  enable_kube_proxy_addon  = true
  kube_proxy_addon_version = "latest"

  enable_vpc_cni_addon  = true
  vpc_cni_addon_version = "latest"

  enable_metrics_server_addon  = true
  metrics_server_addon_version = "latest"

  enable_pod_identity_agent_addon  = true
  pod_identity_agent_addon_version = "latest"

  # CloudMap Service Discovery Configuration
  enable_cloudmap                            = true
  cloudmap_namespace_name                    = "microservices.local"
  cloudmap_namespace_description             = "Service discovery for microservices demo"
  cloudmap_create_ecs_service_discovery_role = false

  # Enable AWS Load Balancer Controller (Official AWS approach)
  enable_aws_load_balancer_controller = true

  # Remove custom CloudMap controller (not needed with official approach)
  enable_cloudmap_controller                = false
  enable_cloudmap_load_balancer_integration = false

  cloudmap_services = {
    "user-service" = {
      name                                  = "user-service"
      description                           = "User management service"
      dns_record_type                       = "A"
      routing_policy                        = "MULTIVALUE"
      health_check_custom_config            = true
      custom_health_check_failure_threshold = 1
    }
    "order-service" = {
      name                                  = "order-service"
      description                           = "Order processing service"
      dns_record_type                       = "A"
      routing_policy                        = "MULTIVALUE"
      health_check_custom_config            = true
      custom_health_check_failure_threshold = 1
    }
  }

  # Sample workloads demonstrating CloudMap integration
  workloads = [
    {
      name      = "user-service"
      namespace = "microservices"
      replicas  = 2
      labels    = { service = "user", tier = "backend" }

      logging = {
        enabled                  = true
        use_cluster_fargate_role = true
      }

      # Enable service with LoadBalancer type for CloudMap integration
      create_service = true
      service_type   = "LoadBalancer" # This triggers CloudMap registration
      service_ports = [{
        name        = "http"
        port        = 80
        target_port = 80
        protocol    = "TCP"
      }]
      service_annotations = {
        "service.beta.kubernetes.io/aws-load-balancer-type"                              = "external"
        "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type"                   = "ip"
        "service.beta.kubernetes.io/aws-load-balancer-scheme"                            = "internal"
        "service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled" = "true"
        "external-dns.alpha.kubernetes.io/hostname"                                      = "user-service.microservices.local"
        "service.beta.kubernetes.io/aws-load-balancer-additional-resource-tags"          = "Environment=dev,Project=cloudmap-demo"
        "service.beta.kubernetes.io/aws-load-balancer-name"                              = "user-service"
        "service.beta.kubernetes.io/aws-load-balancer-attributes"                        = "load_balancing.cross_zone.enabled=true"
      }

      containers = [{
        name  = "user-api"
        image = "public.ecr.aws/nginx/nginx:1.24"
        ports = [{
          containerPort = 80
          protocol      = "TCP"
        }]
        env = [
          {
            name  = "SERVICE_NAME"
            value = "user-service"
          },
          {
            name  = "CLOUDMAP_NAMESPACE"
            value = "microservices.local"
          }
        ]
      }]
    },
    {
      name      = "order-service"
      namespace = "microservices"
      replicas  = 2
      labels    = { service = "order", tier = "backend" }

      logging = {
        enabled                  = true
        use_cluster_fargate_role = true
      }

      # Enable service with LoadBalancer type for CloudMap integration
      create_service = true
      service_type   = "LoadBalancer" # This triggers CloudMap registration
      service_ports = [{
        name        = "http"
        port        = 80
        target_port = 80
        protocol    = "TCP"
      }]
      service_annotations = {
        "service.beta.kubernetes.io/aws-load-balancer-type"                              = "external"
        "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type"                   = "ip"
        "service.beta.kubernetes.io/aws-load-balancer-scheme"                            = "internal"
        "service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled" = "true"
        "external-dns.alpha.kubernetes.io/hostname"                                      = "order-service.microservices.local"
        "service.beta.kubernetes.io/aws-load-balancer-additional-resource-tags"          = "Environment=dev,Project=cloudmap-demo"
        "service.beta.kubernetes.io/aws-load-balancer-name"                              = "order-service"
        "service.beta.kubernetes.io/aws-load-balancer-attributes"                        = "load_balancing.cross_zone.enabled=true"
      }

      containers = [{
        name  = "order-api"
        image = "public.ecr.aws/nginx/nginx:1.24"
        ports = [{
          containerPort = 80
          protocol      = "TCP"
        }]
        env = [
          {
            name  = "SERVICE_NAME"
            value = "order-service"
          },
          {
            name  = "CLOUDMAP_NAMESPACE"
            value = "microservices.local"
          },
          {
            name  = "USER_SERVICE_URL"
            value = "http://user-service.microservices.local"
          }
        ]
      }]
    }
  ]
}

############################################
# Outputs
############################################

output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks_fargate.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = module.eks_fargate.eks_cluster_endpoint
}

output "cloudmap_namespace_id" {
  description = "ID of the created CloudMap namespace"
  value       = module.eks_fargate.cloudmap_namespace_id
}

output "cloudmap_namespace_name" {
  description = "Name of the created CloudMap namespace"
  value       = module.eks_fargate.cloudmap_namespace_name
}

output "cloudmap_services" {
  description = "Map of created CloudMap services"
  value       = module.eks_fargate.cloudmap_services
}

output "cloudmap_controller_namespace" {
  description = "Kubernetes namespace for CloudMap controller"
  value       = module.eks_fargate.cloudmap_controller_namespace
}

output "cloudmap_controller_role_arn" {
  description = "IAM role ARN for CloudMap controller"
  value       = module.eks_fargate.cloudmap_controller_role_arn
}

############################################
# Instructions for Service Discovery
############################################

output "service_discovery_usage" {
  description = "Instructions for using CloudMap service discovery"
  value       = <<-EOT

  CloudMap Service Discovery is now configured!

  Your services can discover each other using these DNS names:
  - user-service.microservices.local
  - order-service.microservices.local

  To test service discovery:
  1. kubectl exec -it <pod-name> -n microservices -- bash
  2. nslookup user-service.microservices.local
  3. curl http://user-service.microservices.local

  The CloudMap controller manages service registration automatically.

  EOT
}
