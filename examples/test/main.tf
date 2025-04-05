terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0"
    }
  }
}

provider "aws" {
  region = "ap-southeast-1"
}

provider "kubernetes" {
  host                   = aws_eks_cluster.cltest.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.cltest.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cltest.token
}

data "aws_eks_cluster_auth" "cltest" {
  name = aws_eks_cluster.cltest.name
}

data "aws_caller_identity" "current" {}

variable "region" {
  default = "ap-southeast-1"
}

locals {
  cluster_name         = "cltest"
  vpc_cidr             = "192.168.0.0/16"
  azs                  = ["ap-southeast-1a", "ap-southeast-1b", "ap-southeast-1c"]
  public_subnet_cidrs  = ["192.168.0.0/19", "192.168.32.0/19", "192.168.64.0/19"]
  private_subnet_cidrs = ["192.168.96.0/19", "192.168.128.0/19", "192.168.160.0/19"]
}

resource "aws_vpc" "cltest" {
  cidr_block           = local.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name                                          = "cltest-vpc"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.cltest.id
  tags = {
    Name = "cltest-igw"
  }
}

resource "aws_subnet" "public" {
  count                   = length(local.azs)
  vpc_id                  = aws_vpc.cltest.id
  cidr_block              = local.public_subnet_cidrs[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true
  tags = {
    Name                                          = "cltest-public-${local.azs[count.index]}"
    "kubernetes.io/role/elb"                      = "1"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }
}

resource "aws_subnet" "private" {
  count             = length(local.azs)
  vpc_id            = aws_vpc.cltest.id
  cidr_block        = local.private_subnet_cidrs[count.index]
  availability_zone = local.azs[count.index]
  tags = {
    Name                                          = "cltest-private-${local.azs[count.index]}"
    "kubernetes.io/role/internal-elb"             = "1"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }
}

resource "aws_eip" "nat" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
  tags = {
    Name = "cltest-nat-gateway"
  }
  depends_on = [aws_internet_gateway.igw]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.cltest.id
  tags = {
    Name = "cltest-public-rt"
  }
}

resource "aws_route" "public_internet_access" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  count  = length(local.azs)
  vpc_id = aws_vpc.cltest.id
  tags = {
    Name = "cltest-private-rt-${local.azs[count.index]}"
  }
}

resource "aws_route" "private_nat" {
  count                  = length(local.azs)
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
}

resource "aws_route_table_association" "private" {
  count          = length(local.azs)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

resource "aws_eks_cluster" "cltest" {
  name     = local.cluster_name
  role_arn = aws_iam_role.eks_cluster.arn
  version  = "1.29"

  vpc_config {
    subnet_ids             = aws_subnet.private[*].id
    endpoint_public_access = true
  }

  depends_on = [aws_iam_role_policy_attachment.eks_cluster_AmazonEKSClusterPolicy]
  tags = {
    Name = "cltest-eks"
  }
}

resource "aws_iam_role" "eks_cluster" {
  name = "cltest-eks-cluster"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_AmazonEKSClusterPolicy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role" "fargate_pod_execution" {
  name = "${local.cluster_name}-eks-fargate-pod"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "eks-fargate-pods.amazonaws.com"
        },
        Action = "sts:AssumeRole",
        Condition = {
          ArnLike = {
            "aws:SourceArn" = "arn:aws:eks:${var.region}:${data.aws_caller_identity.current.account_id}:fargateprofile/${local.cluster_name}/*"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "fargate_execution_policy" {
  role       = aws_iam_role.fargate_pod_execution.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
}

resource "aws_eks_fargate_profile" "coredns" {
  cluster_name           = aws_eks_cluster.cltest.name
  fargate_profile_name   = "coredns"
  pod_execution_role_arn = aws_iam_role.fargate_pod_execution.arn
  subnet_ids             = aws_subnet.private[*].id

  selector {
    namespace = "kube-system"
    labels = {
      k8s-app = "kube-dns"
    }
  }

  depends_on = [aws_eks_cluster.cltest]
}

resource "aws_eks_addon" "coredns" {
  cluster_name             = aws_eks_cluster.cltest.name
  addon_name               = "coredns"
  addon_version            = "v1.11.4-eksbuild.2"
  resolve_conflicts        = "OVERWRITE"
  service_account_role_arn = aws_iam_role.fargate_pod_execution.arn

  depends_on = [aws_eks_fargate_profile.coredns]
}

resource "aws_eks_addon" "vpc_cni" {
  cluster_name      = aws_eks_cluster.cltest.name
  addon_name        = "vpc-cni"
  resolve_conflicts = "OVERWRITE"
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name      = aws_eks_cluster.cltest.name
  addon_name        = "kube-proxy"
  resolve_conflicts = "OVERWRITE"
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "vpc_id" {
  value = aws_vpc.cltest.id
}

output "eks_cluster_name" {
  value = aws_eks_cluster.cltest.name
}

output "eks_cluster_endpoint" {
  value = aws_eks_cluster.cltest.endpoint
}

output "eks_cluster_ca" {
  value = aws_eks_cluster.cltest.certificate_authority.0.data
}
