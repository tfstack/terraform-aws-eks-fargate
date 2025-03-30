terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# Generate a random string as suffix
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# Data Sources
data "aws_availability_zones" "available" {}

# VPC Module
module "vpc" {
  source = "tfstack/vpc/aws"

  vpc_name           = "eks-test"
  vpc_cidr           = "10.0.0.0/16"
  availability_zones = slice(data.aws_availability_zones.available.names, 0, 3)

  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnets = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  jumphost_instance_create = false

  create_igw = true
  ngw_type   = "single"

  tags = {
    Name = "eks-test"
  }

  enable_eks_tags        = true
  eks_cluster_name       = "eks-test"
  enable_s3_vpc_endpoint = false
}

# Output variables used in tests
output "private_subnet_cidrs" {
  value = module.vpc.private_subnet_cidrs
}

output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}

output "suffix" {
  value = random_string.suffix.result
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "service_cidr" {
  value = module.vpc.vpc_cidr
}
