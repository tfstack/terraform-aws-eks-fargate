# Example usage of terraform-aws-eks-fargate module

This is a practical example demonstrating the use of the `terraform-aws-eks-fargate` module to deploy an EKS cluster running entirely on Fargate. It sets up a VPC, EKS cluster, managed add-ons, namespaces, Fargate profiles, and sample workloads.

## Features

* Deploys an EKS cluster configured for Fargate
* Enables common EKS managed add-ons (VPC CNI, CoreDNS, kube-proxy, metrics-server, pod identity agent)
* Creates custom Fargate profiles and namespaces
* Deploys a sample NGINX logger workload to validate configuration

## Prerequisites

* Terraform v1.3+
* AWS CLI configured with appropriate permissions

## Usage

````hcl
############################################
# Terraform & Provider Configuration
############################################

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.97.0"
    }
  }
}

provider "aws" {
  region = "ap-southeast-1"
}

############################################
# Data Sources
############################################

data "aws_availability_zones" "available" {}

data "http" "my_public_ip" {
  url = "https://ipinfo.io/ip"
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
  name      = "cltest"
  base_name = "${local.name}-${random_string.suffix.result}"

  eks_cluster_version = "1.32"
  service_cidr        = "10.100.0.0/16"

  tags = {
    Environment = "dev"
    Project     = "example"
  }
}

############################################
# VPC Configuration
############################################

module "vpc" {
  source = "tfstack/vpc/aws"

  vpc_name           = local.base_name
  vpc_cidr           = "10.0.0.0/16"
  availability_zones = slice(data.aws_availability_zones.available.names, 0, 3)

  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnets = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  jumphost_instance_create = false

  create_igw = true
  ngw_type   = "single"

  tags = local.tags

  enable_eks_tags        = true
  eks_cluster_name       = local.name
  enable_s3_vpc_endpoint = false
}

############################################
# EKS Fargate Root Module
############################################

module "eks_fargate" {
  source = "../.."

  vpc_id          = module.vpc.vpc_id
  cluster_name    = local.name
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

  cluster_enabled_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]

  enable_cluster_encryption = false
  enable_oidc               = true
  eks_log_prevent_destroy   = false
  eks_log_retention_days    = 1

  enable_cloudwatch_observability = true

  namespaces = [
    {
      name = "demo"
      labels = {
        "purpose" = "e2e"
      }
    }
  ]

  fargate_profiles = [
    {
      name       = "demo"
      subnet_ids = module.vpc.private_subnet_ids

      selectors = [
        {
          namespace = "demo"
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

  workloads = [
    {
      name      = "logger-test"
      namespace = "demo"
      replicas  = 2
      labels    = { purpose = "e2e" }

      logging = {
        enabled                  = true
        use_cluster_fargate_role = true
      }

      irsa = {
        enabled                   = false
        use_cluster_oidc_provider = false
        policy_arns               = []
      }

      containers = [{
        name    = "logger"
        image   = "public.ecr.aws/bitnami/nginx"
        command = ["/bin/sh", "-c"]
        args    = ["while true; do echo hello from nginx $(date); sleep 5; done"]
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

output "fargate_profile_names" {
  description = "Names of the created Fargate profiles"
  value       = module.eks_fargate.fargate_profile_names
}

output "fargate_profile_selectors" {
  description = "Selectors per Fargate profile"
  value       = module.eks_fargate.fargate_profile_selectors
}

output "addon_versions" {
  description = "EKS managed addon versions"
  value       = module.eks_fargate.eks_addons
}

output "namespace_names" {
  description = "List of created Kubernetes namespaces"
  value       = module.eks_fargate.namespace_names
}
````

---

## 📅 Inputs (Key Parameters)

| Name                 | Description                                   | Type     | Required   |
| -------------------- | --------------------------------------------- | -------- | ---------- |
| `cluster_name`       | Name of the EKS cluster                       | `string` | ✅ Yes      |
| `vpc_id`             | VPC ID to deploy the EKS cluster              | `string` | ✅ Yes      |
| `cluster_version`    | Kubernetes version (e.g. `1.32`)              | `string` | ✅ Yes      |
| `cluster_vpc_config` | Subnet and endpoint config                    | `object` | ✅ Yes      |
| `tags`               | Tags to apply to resources                    | `map`    | ✅ Yes      |
| `workloads`          | List of workloads to deploy                   | `list`   | ✅ Yes      |
| `fargate_profiles`   | Custom Fargate profile configuration          | `list`   | ⬛ Optional |
| `enable_*_addon`     | Toggle managed addons (e.g. `enable_coredns`) | `bool`   | ⬛ Optional |

---

## 📄 Outputs

| Name                        | Description                              |
| --------------------------- | ---------------------------------------- |
| `cluster_name`              | Name of the EKS cluster                  |
| `cluster_endpoint`          | EKS cluster API endpoint                 |
| `fargate_profile_names`     | Names of the created Fargate profiles    |
| `fargate_profile_selectors` | Selectors per Fargate profile            |
| `addon_versions`            | Installed version of each EKS addon      |
| `namespace_names`           | List of namespaces created by the module |

---

💾 License

This module is distributed under the MIT License. See [LICENSE](./LICENSE) for full details.
