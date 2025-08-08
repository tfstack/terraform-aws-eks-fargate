############################################
# Terraform & Provider Configuration
############################################

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.20.0"
    }
    time = {
      source = "hashicorp/time"
    }
  }
}
############################################
# Example Switches
############################################

variable "install_mcs_prereqs" {
  description = "Install MCS CRDs and ClusterProperty resources (run in the second apply)."
  type        = bool
  default     = true
}

variable "enable_mcs_controller" {
  description = "Enable the MCS controller in the module (set true in the second apply)."
  type        = bool
  default     = false
}

variable "enable_demo" {
  description = "Deploy the demo workload and CloudMap service."
  type        = bool
  default     = false
}

# Second-stage switch: create ClusterProperty objects after CRDs exist
variable "create_cluster_identity" {
  description = "Create ClusterProperty (cluster/clusterset) after CRDs have been installed."
  type        = bool
  default     = false
}

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
  name                = "test"
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
    Project     = "service-discovery"
  }

  cloudmap_services = {
    "client-hello" = {
      name                                  = "client-hello"
      description                           = "Hello world demo service"
      dns_ttl                               = 60
      routing_policy                        = "MULTIVALUE"
      health_check_custom_config            = true
      custom_health_check_failure_threshold = 1
      tags = {
        Service     = "hello"
        Environment = "dev"
      }
    }
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
  # A single NAT gateway is used instead of multiple for cost efficiency.
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

  enable_cluster_encryption = false
  enable_oidc               = true
  eks_log_prevent_destroy   = false
  eks_log_retention_days    = 1

  # Enable CloudWatch observability
  enable_cloudwatch_observability = true

  # Create demo namespace for workload
  namespaces = [
    {
      name = "demo"
    }
  ]

  # Configure Fargate profiles
  fargate_profiles = [
    {
      name       = "kube-system"
      subnet_ids = module.vpc.private_subnet_ids

      selectors = [
        {
          namespace = "kube-system"
          labels    = { "k8s-app" = "kube-dns" }
        }
      ]
    },
    {
      name       = "demo"
      subnet_ids = module.vpc.private_subnet_ids

      selectors = [
        {
          namespace = "demo"
        }
      ]
    },
    {
      name       = "mcs-controller"
      subnet_ids = module.vpc.private_subnet_ids

      selectors = [
        {
          namespace = "cloud-map-mcs-system"
        }
      ]
    }
  ]

  # Enable basic addons
  enable_vpc_cni_addon    = true
  enable_coredns_addon    = true
  enable_kube_proxy_addon = true

  # CloudMap Service Discovery Configuration
  enable_cloudmap                            = true
  cloudmap_namespace_name                    = "svc.local"
  cloudmap_namespace_description             = "Private service discovery for EKS Fargate"
  cloudmap_services                          = var.enable_demo ? local.cloudmap_services : {}
  cloudmap_create_ecs_service_discovery_role = false

  enable_mcs_controller  = var.enable_mcs_controller
  mcs_controller_version = "v0.3.1"

  # Configure demo workload with service discovery
  workloads = var.enable_demo ? [
    {
      name      = "client-hello"
      namespace = "demo"
      replicas  = 2
      labels    = { service = "hello" }

      logging = {
        enabled                  = true
        use_cluster_fargate_role = true
      }

      irsa = {
        enabled                   = false
        use_cluster_oidc_provider = false
        policy_arns               = []
      }

      # Service configuration for CloudMap integration
      create_service = true
      service_type   = "ClusterIP"
      service_ports = [{
        name        = "http"
        port        = 80
        target_port = 80
        protocol    = "TCP"
      }]
      service_annotations = {}

      containers = [{
        name  = "nginx"
        image = "nginxdemos/hello:plain-text"
        ports = [{
          containerPort = 80
          protocol      = "TCP"
        }]
      }]
    }
  ] : []
}

############################################
# Kubernetes provider (used in second apply)
############################################

provider "kubernetes" {
  host                   = module.eks_fargate.eks_cluster_endpoint
  cluster_ca_certificate = module.eks_fargate.eks_cluster_ca_cert
  token                  = module.eks_fargate.eks_cluster_auth_token
}

# ############################################
# # MCS Prerequisites (second apply only)
# ############################################

# resource "kubernetes_manifest" "crd_serviceexport" {
#   count = var.install_mcs_prereqs ? 1 : 0
#   manifest = {
#     apiVersion = "apiextensions.k8s.io/v1"
#     kind       = "CustomResourceDefinition"
#     metadata   = { name = "serviceexports.multicluster.x-k8s.io" }
#     spec = {
#       group    = "multicluster.x-k8s.io"
#       scope    = "Namespaced"
#       names    = { plural = "serviceexports", singular = "serviceexport", kind = "ServiceExport", shortNames = ["se"] }
#       versions = [{ name = "v1alpha1", served = true, storage = true, schema = { openAPIV3Schema = { type = "object" } } }]
#     }
#   }
# }

# resource "kubernetes_manifest" "crd_serviceimport" {
#   count = var.install_mcs_prereqs ? 1 : 0
#   manifest = {
#     apiVersion = "apiextensions.k8s.io/v1"
#     kind       = "CustomResourceDefinition"
#     metadata   = { name = "serviceimports.multicluster.x-k8s.io" }
#     spec = {
#       group    = "multicluster.x-k8s.io"
#       scope    = "Cluster"
#       names    = { plural = "serviceimports", singular = "serviceimport", kind = "ServiceImport", shortNames = ["si"] }
#       versions = [{ name = "v1alpha1", served = true, storage = true, schema = { openAPIV3Schema = { type = "object" } } }]
#     }
#   }
# }

# resource "kubernetes_manifest" "crd_clusterproperty" {
#   count = var.install_mcs_prereqs ? 1 : 0
#   manifest = {
#     apiVersion = "apiextensions.k8s.io/v1"
#     kind       = "CustomResourceDefinition"
#     metadata = {
#       name = "clusterproperties.about.k8s.io"
#       annotations = {
#         # Required for protected API groups
#         "api-approved.kubernetes.io" = "https://github.com/kubernetes/enhancements/pull/1111"
#       }
#     }
#     spec = {
#       group = "about.k8s.io"
#       scope = "Cluster"
#       names = { plural = "clusterproperties", singular = "clusterproperty", kind = "ClusterProperty", shortNames = ["cp"] }
#       versions = [{
#         name    = "v1alpha1"
#         served  = true
#         storage = true
#         schema  = { openAPIV3Schema = { type = "object", properties = { spec = { type = "object", properties = { value = { type = "string" } } } } } }
#       }]
#     }
#   }
# }

# resource "time_sleep" "wait_for_crds" {
#   count           = var.install_mcs_prereqs ? 1 : 0
#   create_duration = "20s"
#   depends_on = [
#     kubernetes_manifest.crd_serviceexport,
#     kubernetes_manifest.crd_serviceimport,
#     kubernetes_manifest.crd_clusterproperty,
#   ]
# }

# resource "kubernetes_manifest" "cluster_property_cluster" {
#   count = var.create_cluster_identity ? 1 : 0
#   manifest = {
#     apiVersion = "about.k8s.io/v1alpha1"
#     kind       = "ClusterProperty"
#     metadata   = { name = "cluster.clusterset.k8s.io" }
#     spec       = { value = module.eks_fargate.cluster_name }
#   }
# }

# resource "kubernetes_manifest" "cluster_property_clusterset" {
#   count = var.create_cluster_identity ? 1 : 0
#   manifest = {
#     apiVersion = "about.k8s.io/v1alpha1"
#     kind       = "ClusterProperty"
#     metadata   = { name = "clusterset.k8s.io" }
#     spec       = { value = "${module.eks_fargate.cluster_name}-clusterset" }
#   }
# }

# ############################################
# # Export demo service (triggers Cloud Map registration)
# ############################################

# resource "kubernetes_manifest" "demo_serviceexport" {
#   count = var.enable_demo && var.enable_mcs_controller && var.create_cluster_identity ? 1 : 0
#   manifest = {
#     apiVersion = "multicluster.x-k8s.io/v1alpha1"
#     kind       = "ServiceExport"
#     metadata   = { name = "client-hello", namespace = "demo" }
#   }
#   depends_on = [
#     kubernetes_manifest.crd_serviceexport
#   ]
# }

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

output "fargate_profile_names" {
  description = "Names of the created Fargate profiles"
  value       = module.eks_fargate.fargate_profile_names
}

output "namespace_names" {
  description = "List of created Kubernetes namespaces"
  value       = module.eks_fargate.namespace_names
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

# output "mcs_controller_namespace" {
#   description = "Namespace where the MCS controller is deployed"
#   value       = module.eks_fargate.mcs_controller_namespace
# }

# output "mcs_controller_service_account" {
#   description = "Service account name for the MCS controller"
#   value       = module.eks_fargate.mcs_controller_service_account
# }

# output "mcs_controller_policy_arn" {
#   description = "IAM policy ARN for the MCS controller CloudMap permissions"
#   value       = module.eks_fargate.mcs_controller_policy_arn
# }
