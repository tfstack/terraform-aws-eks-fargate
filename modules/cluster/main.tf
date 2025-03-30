#########################################
# AWS Account & Region Data
#########################################

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

#########################################
# Local Values
#########################################

locals {
  # Extracts IAM role name from caller ARN
  executor_role_name = split("/", data.aws_caller_identity.current.arn)[1]

  # Determines EKS cluster version, allows "latest" or null
  resolved_cluster_version = (
    var.cluster_version == null || var.cluster_version == "latest"
    ? null
    : var.cluster_version
  )
}

##############################
# IAM Role for EKS Fargate Cluster
##############################

resource "aws_iam_role" "eks_fargate_cluster" {
  name = "${var.cluster_name}-eks-fargate-cluster"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
      Action = [
        "sts:AssumeRole",
        "sts:TagSession"
      ]
    }]
  })

  tags = merge(
    { "Name" = "${var.cluster_name}-eks-fargate-cluster" },
    var.tags
  )
}

resource "aws_iam_role_policy_attachment" "eks_fargate_cluster" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
    "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  ])

  role       = aws_iam_role.eks_fargate_cluster.name
  policy_arn = each.value
}

##############################
# IAM Role for Fargate Pods
##############################

resource "aws_iam_role" "eks_fargate_pod" {
  name = "${var.cluster_name}-eks-fargate-pod"

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
            "aws:SourceArn" = "arn:aws:eks:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:fargateprofile/${var.cluster_name}/*"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_fargate_pod" {
  role       = aws_iam_role.eks_fargate_pod.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
}

resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  version  = local.resolved_cluster_version
  role_arn = aws_iam_role.eks_fargate_cluster.arn

  #######################################
  # Logging and Monitoring
  #######################################
  enabled_cluster_log_types = var.cluster_enabled_log_types

  depends_on = [
    aws_cloudwatch_log_group.eks_cluster_with_prevent_destroy,
    aws_cloudwatch_log_group.eks_cluster_without_prevent_destroy,
    aws_cloudwatch_log_group.eks_logs_with_prevent_destroy,
    aws_cloudwatch_log_group.eks_logs_without_prevent_destroy
  ]

  #######################################
  # Access Control
  #######################################
  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = false
  }

  #######################################
  # Networking
  #######################################
  vpc_config {
    security_group_ids = compact(distinct(concat(
      var.cluster_vpc_config.security_group_ids,
      var.create_security_group ? [aws_security_group.cluster_control_plane[0].id] : []
    )))
    subnet_ids              = var.cluster_vpc_config.subnet_ids
    endpoint_private_access = var.cluster_vpc_config.endpoint_private_access
    endpoint_public_access  = var.cluster_vpc_config.endpoint_public_access
    public_access_cidrs     = var.cluster_vpc_config.public_access_cidrs
  }

  kubernetes_network_config {
    ip_family         = "ipv4"
    service_ipv4_cidr = var.cluster_vpc_config.service_cidr
    elastic_load_balancing {
      enabled = false # REQUIRED when EKS Auto Mode is enabled
    }
  }

  #######################################
  # Compute
  #######################################
  compute_config {
    enabled = false # REQUIRED when EKS Auto Mode is enabled
  }

  #######################################
  # Encryption
  #######################################
  dynamic "encryption_config" {
    for_each = var.enable_cluster_encryption ? [1] : []
    content {
      provider {
        key_arn = aws_kms_key.eks[0].arn
      }
      resources = ["secrets"]
    }
  }

  #######################################
  # Storage
  #######################################
  storage_config {
    block_storage {
      enabled = false # REQUIRED when EKS Auto Mode is enabled
    }
  }

  #######################################
  # Upgrade & Zonal Shift
  #######################################
  upgrade_policy {
    support_type = try(var.cluster_upgrade_policy.support_type, null)
  }

  zonal_shift_config {
    enabled = try(var.cluster_zonal_shift_config.enabled, false)
  }

  #######################################
  # Meta & Tags
  #######################################
  bootstrap_self_managed_addons = false # REQUIRED when EKS Auto Mode is enabled

  tags = merge(
    {
      "Name"                                        = "${var.cluster_name}-eks-fargate-cluster"
      "alpha.eksctl.io/cluster-name"                = var.cluster_name
      "eksctl.cluster.k8s.io/v1alpha1/cluster-name" = var.cluster_name
    },
    var.tags
  )

  timeouts {
    create = try(var.timeouts.create, null)
    update = try(var.timeouts.update, null)
    delete = try(var.timeouts.delete, null)
  }
}

#########################################
# EKS Access Entry for Terraform Executor
#########################################

resource "aws_eks_access_entry" "terraform_executor" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.executor_role_name}"
}

resource "aws_eks_access_policy_association" "terraform_executor" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = aws_eks_access_entry.terraform_executor.principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}

#######################################
# Auth for cluster access
#######################################
data "aws_eks_cluster_auth" "this" {
  name = aws_eks_cluster.this.name
}

##############################
# CloudWatch Log Group: EKS Cluster Logs
##############################

resource "aws_cloudwatch_log_group" "eks_cluster_with_prevent_destroy" {
  count = var.eks_log_prevent_destroy ? 1 : 0

  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.eks_log_retention_days

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name = "${var.cluster_name}-cluster"
  }
}

resource "aws_cloudwatch_log_group" "eks_cluster_without_prevent_destroy" {
  count = var.eks_log_prevent_destroy ? 0 : 1

  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.eks_log_retention_days

  lifecycle {
    prevent_destroy = false
  }

  tags = {
    Name = "${var.cluster_name}-cluster"
  }
}

##############################
# CloudWatch Log Group: EKS General Logs
##############################

resource "aws_cloudwatch_log_group" "eks_logs_with_prevent_destroy" {
  count = var.eks_log_prevent_destroy ? 1 : 0

  name              = "/aws/eks/${var.cluster_name}/logs"
  retention_in_days = var.eks_log_retention_days

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name = "${var.cluster_name}-logs"
  }
}

resource "aws_cloudwatch_log_group" "eks_logs_without_prevent_destroy" {
  count = var.eks_log_prevent_destroy ? 0 : 1

  name              = "/aws/eks/${var.cluster_name}/logs"
  retention_in_days = var.eks_log_retention_days

  lifecycle {
    prevent_destroy = false
  }

  tags = {
    Name = "${var.cluster_name}-logs"
  }
}

#########################################
# Security Group for EKS Cluster
#########################################

resource "aws_security_group" "cluster_control_plane" {
  count = var.create_security_group ? 1 : 0

  name        = "${var.cluster_name}-cluster-control-plane"
  description = "Communication between the control plane and worker nodegroups"
  vpc_id      = var.vpc_id

  #######################################
  # Egress Rules
  #######################################

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(
    {
      "Name" = "${var.cluster_name}-cluster-control-plane"
    },
    var.tags
  )
}

resource "aws_security_group" "cluster_nodes" {
  count = var.create_security_group ? 1 : 0

  name        = "${var.cluster_name}-cluster-nodes"
  description = "Communication between all nodes in the cluster"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow nodes to communicate with each other (all ports)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  ingress {
    description = "Allow managed and unmanaged nodes to communicate with each other (all ports)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"

    security_groups = [
      aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    {
      "Name" = "${var.cluster_name}-cluster-nodes"
    },
    var.tags
  )
}

##############################
# KMS Key for EKS Cluster Encryption
##############################

resource "aws_kms_key" "eks" {
  count = var.enable_cluster_encryption ? 1 : 0

  description             = "EKS cluster encryption key"
  enable_key_rotation     = true
  deletion_window_in_days = 7
}

resource "aws_kms_alias" "eks" {
  count = var.enable_cluster_encryption ? 1 : 0

  name          = "alias/${var.cluster_name}-eks"
  target_key_id = aws_kms_key.eks[0].id
}

#########################################
# TLS Certificate for EKS OIDC (IRSA)
#########################################

data "tls_certificate" "eks_oidc" {
  count = var.enable_oidc ? 1 : 0

  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

#########################################
# IAM OpenID Connect Provider for EKS (IRSA)
#########################################

resource "aws_iam_openid_connect_provider" "this" {
  count = var.enable_oidc ? 1 : 0

  url            = aws_eks_cluster.this.identity[0].oidc[0].issuer
  client_id_list = ["sts.amazonaws.com"]

  thumbprint_list = [
    data.tls_certificate.eks_oidc[0].certificates[0].sha1_fingerprint
  ]
}
