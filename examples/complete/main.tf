############################################
# Provider Configuration
############################################

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.84.0"
    }
  }
}

provider "aws" {
  region = "ap-southeast-1"
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
# Data Sources
############################################

# data "aws_region" "current" {}
data "aws_availability_zones" "available" {}
# data "aws_caller_identity" "current" {}

data "http" "my_public_ip" {
  url = "http://ifconfig.me/ip"
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

  eic_subnet        = "none"
  eic_ingress_cidrs = ["${data.http.my_public_ip.response_body}/32"]

  jumphost_subnet              = "10.0.0.0/24"
  jumphost_allow_egress        = true
  jumphost_instance_create     = true
  jumphost_user_data_file      = "${path.module}/external/cloud-init.sh"
  jumphost_log_prevent_destroy = false

  create_igw = true
  ngw_type   = "single"

  tags = local.tags

  enable_eks_tags        = true
  enable_s3_vpc_endpoint = true
}

module "eks_fargate" {
  source = "../.."

  ############################################
  # General Config
  ############################################
  vpc_id          = module.vpc.vpc_id
  cluster_name    = local.name
  cluster_version = "latest"

  tags = local.tags

  ############################################
  # Networking
  ############################################
  cluster_vpc_config = {
    subnet_ids           = concat(module.vpc.private_subnet_ids, module.vpc.public_subnet_ids)
    private_subnet_ids   = module.vpc.private_subnet_ids
    private_access_cidrs = module.vpc.private_subnet_cidrs
    public_access_cidrs = [
      "${data.http.my_public_ip.response_body}/32"
    ] # exercise with cautious
    service_cidr = local.service_cidr

    security_group_ids      = []
    endpoint_private_access = false
    endpoint_public_access  = true # exercise with cautious
  }

  ############################################
  # Logging & Monitoring
  ############################################
  cluster_enabled_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]

  enable_cluster_encryption     = false
  enable_elastic_load_balancing = false
}

output "all_module_outputs" {
  description = "All outputs from the EKS Fargate module"
  value       = module.eks_fargate
}
