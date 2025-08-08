#########################################
# Data Sources
#########################################

data "aws_eks_cluster_versions" "available" {}

data "aws_eks_addon_version" "latest" {
  for_each = {
    for a in local.addons : a.name => a
    if a.version == null || a.version == "" || a.version == "latest"
  }

  addon_name         = each.value.name
  kubernetes_version = local.k8s_version
  most_recent        = true
}

#########################################
# Locals
#########################################

locals {
  latest_k8s_version = reverse(sort([
    for v in data.aws_eks_cluster_versions.available.cluster_versions : v.cluster_version
  ]))[0]

  k8s_version = var.cluster_version == "latest" ? local.latest_k8s_version : var.cluster_version

  addons = [
    {
      name    = "vpc-cni"
      enabled = var.enable_addons.vpc_cni
      version = var.addon_versions["vpc_cni"]
    },
    {
      name    = "coredns"
      enabled = var.enable_addons.coredns
      version = var.addon_versions["coredns"]
    },
    {
      name    = "kube-proxy"
      enabled = var.enable_addons.kube_proxy
      version = var.addon_versions["kube_proxy"]
    },
    {
      name    = "metrics-server"
      enabled = var.enable_addons.metrics_server
      version = var.addon_versions["metrics_server"]
    },
    {
      name    = "eks-pod-identity-agent"
      enabled = var.enable_addons.pod_identity
      version = var.addon_versions["pod_identity"]
    },
    # AWS Load Balancer Controller is not available as an EKS addon
    # It needs to be installed separately using Helm or the official installation method
  ]
}

#########################################
# EKS Addons Configuration
#########################################

resource "aws_eks_addon" "this" {
  for_each = {
    for addon in local.addons : addon.name => addon
    if addon.enabled
  }

  cluster_name = var.cluster_name
  addon_name   = each.value.name
  addon_version = (
    contains(["", null, "latest"], each.value.version)
    ? data.aws_eks_addon_version.latest[each.key].version
    : each.value.version
  )

  tags = var.tags
}

# Manage CoreDNS Corefile to enable multicluster, if requested
// CoreDNS Corefile management removed for clean baseline

# Extra RBAC for CoreDNS to read EndpointSlices and MCS CRDs when CoreDNS addon is enabled
// Extra CoreDNS RBAC for MCS CRDs removed for clean baseline

# AWS Load Balancer Controller is now handled by the main addons loop above

#########################################
# AWS Load Balancer Controller IAM Role
#########################################

resource "aws_iam_role" "aws_load_balancer_controller" {
  count = var.enable_aws_load_balancer_controller ? 1 : 0

  name = "${var.cluster_name}-aws-load-balancer-controller"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(var.oidc_provider_arn, "/^(.*provider/)/", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
            "${replace(var.oidc_provider_arn, "/^(.*provider/)/", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge(
    { "Name" = "${var.cluster_name}-aws-load-balancer-controller" },
    var.tags
  )
}

#########################################
# AWS Load Balancer Controller Policy
#########################################

resource "aws_iam_policy" "aws_load_balancer_controller" {
  count = var.enable_aws_load_balancer_controller ? 1 : 0

  name        = "${var.cluster_name}-aws-load-balancer-controller"
  description = "Policy for AWS Load Balancer Controller"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "iam:CreateServiceLinkedRole"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "iam:AWSServiceName" = "elasticloadbalancing.amazonaws.com"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeAccountAttributes",
          "ec2:DescribeAddresses",
          "ec2:DescribeInternetGateways",
          "ec2:DescribeVpcs",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeInstances",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeTags",
          "ec2:GetCoipPoolUsage",
          "ec2:DescribeCoipPools",
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeLoadBalancerAttributes",
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:DescribeListenerCertificates",
          "elasticloadbalancing:DescribeSSLPolicies",
          "elasticloadbalancing:DescribeRules",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeTargetGroupAttributes",
          "elasticloadbalancing:DescribeTargetHealth",
          "elasticloadbalancing:DescribeTags"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "cognito-idp:DescribeUserPoolClient",
          "acm:ListCertificates",
          "acm:DescribeCertificate",
          "iam:ListServerCertificates",
          "iam:GetServerCertificate",
          "waf-regional:GetWebACL",
          "waf-regional:GetWebACLForResource",
          "waf-regional:AssociateWebACL",
          "waf-regional:DisassociateWebACL",
          "wafv2:GetWebACL",
          "wafv2:GetWebACLForResource",
          "wafv2:AssociateWebACL",
          "wafv2:DisassociateWebACL",
          "shield:DescribeProtection",
          "shield:GetSubscriptionState",
          "shield:DeleteProtection",
          "shield:CreateProtection",
          "shield:DescribeSubscription",
          "shield:ListProtections"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateSecurityGroup",
          "ec2:CreateTags"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "ec2:CreateAction" = "CreateSecurityGroup"
          }
          Null = {
            "aws:RequestTag/elbv2.k8s.aws/resource" = "false"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateTags"
        ]
        Resource = "arn:aws:ec2:*:*:security-group/*"
        Condition = {
          Null = {
            "aws:RequestTag/elbv2.k8s.aws/resource"  = "true"
            "aws:ResourceTag/elbv2.k8s.aws/resource" = "false"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateSecurityGroup",
          "ec2:CreateTags"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "ec2:CreateAction" = "CreateSecurityGroup"
          }
          StringLike = {
            "aws:RequestTag/elbv2.k8s.aws/resource" = "shared"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateTags"
        ]
        Resource = "arn:aws:ec2:*:*:security-group/*"
        Condition = {
          StringLike = {
            "aws:RequestTag/elbv2.k8s.aws/resource" = "shared"
          }
          StringEquals = {
            "aws:ResourceTag/elbv2.k8s.aws/resource" = "shared"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:CreateLoadBalancer",
          "elasticloadbalancing:CreateTargetGroup"
        ]
        Resource = "*"
        Condition = {
          Null = {
            "aws:RequestTag/elbv2.k8s.aws/resource" = "false"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:CreateListener",
          "elasticloadbalancing:DeleteListener",
          "elasticloadbalancing:CreateRule",
          "elasticloadbalancing:ModifyRule",
          "elasticloadbalancing:DeleteRule",
          "elasticloadbalancing:SetWebAcl",
          "elasticloadbalancing:ModifyListener"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:AddTags",
          "elasticloadbalancing:RemoveTags"
        ]
        Resource = [
          "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
          "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
          "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
        ]
        Condition = {
          Null = {
            "aws:RequestTag/elbv2.k8s.aws/resource"  = "true"
            "aws:ResourceTag/elbv2.k8s.aws/resource" = "false"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:AddTags",
          "elasticloadbalancing:RemoveTags"
        ]
        Resource = [
          "arn:aws:elasticloadbalancing:*:*:listener/net/*/*/*",
          "arn:aws:elasticloadbalancing:*:*:listener/app/*/*/*",
          "arn:aws:elasticloadbalancing:*:*:listener-rule/net/*/*/*",
          "arn:aws:elasticloadbalancing:*:*:listener-rule/app/*/*/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:ModifyLoadBalancerAttributes",
          "elasticloadbalancing:SetIpAddressType",
          "elasticloadbalancing:SetSecurityGroups",
          "elasticloadbalancing:SetSubnets",
          "elasticloadbalancing:DeleteLoadBalancer",
          "elasticloadbalancing:ModifyTargetGroup",
          "elasticloadbalancing:ModifyTargetGroupAttributes",
          "elasticloadbalancing:DeleteTargetGroup",
          "elasticloadbalancing:RegisterTargets",
          "elasticloadbalancing:DeregisterTargets",
          "elasticloadbalancing:SetWebAcl",
          "elasticloadbalancing:ModifyListener",
          "elasticloadbalancing:AddListenerCertificates",
          "elasticloadbalancing:RemoveListenerCertificates",
          "elasticloadbalancing:ModifyRule"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:CreateServiceLinkedRole",
          "iam:AttachRolePolicy",
          "iam:PutRolePolicy"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "iam:AWSServiceName" = "elasticloadbalancing.amazonaws.com"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "cognito-idp:CreateUserPoolClient"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "acm:AddTagsToCertificate",
          "acm:RemoveTagsFromCertificate"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "acm:ResourceTag/elbv2.k8s.aws/resource" = "shared"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "tag:GetResources",
          "tag:TagResources"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestTag/elbv2.k8s.aws/resource" = "shared"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:AddTags"
        ]
        Resource = [
          "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
          "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
          "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
        ]
        Condition = {
          StringEquals = {
            "aws:RequestTag/elbv2.k8s.aws/resource" = "shared"
          }
          StringEquals = {
            "aws:ResourceTag/elbv2.k8s.aws/resource" = "shared"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "tag:GetResources",
          "tag:TagResources"
        ]
        Resource = "*"
        Condition = {
          StringLike = {
            "aws:RequestTag/elbv2.k8s.aws/resource" = "shared"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:AddTags"
        ]
        Resource = [
          "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
          "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
          "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
        ]
        Condition = {
          StringLike = {
            "aws:RequestTag/elbv2.k8s.aws/resource" = "shared"
          }
          StringEquals = {
            "aws:ResourceTag/elbv2.k8s.aws/resource" = "shared"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:CreateListener"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestTag/elbv2.k8s.aws/resource" = "shared"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:CreateListener"
        ]
        Resource = "arn:aws:elasticloadbalancing:*:*:listener/net/*/*/*"
        Condition = {
          StringEquals = {
            "aws:RequestTag/elbv2.k8s.aws/resource" = "shared"
          }
          StringEquals = {
            "aws:ResourceTag/elbv2.k8s.aws/resource" = "shared"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:CreateListener"
        ]
        Resource = "arn:aws:elasticloadbalancing:*:*:listener/app/*/*/*"
        Condition = {
          StringEquals = {
            "aws:RequestTag/elbv2.k8s.aws/resource" = "shared"
          }
          StringEquals = {
            "aws:ResourceTag/elbv2.k8s.aws/resource" = "shared"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:CreateRule"
        ]
        Resource = "arn:aws:elasticloadbalancing:*:*:listener-rule/app/*/*/*"
        Condition = {
          StringEquals = {
            "aws:RequestTag/elbv2.k8s.aws/resource" = "shared"
          }
          StringEquals = {
            "aws:ResourceTag/elbv2.k8s.aws/resource" = "shared"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:CreateRule"
        ]
        Resource = "arn:aws:elasticloadbalancing:*:*:listener-rule/net/*/*/*"
        Condition = {
          StringEquals = {
            "aws:RequestTag/elbv2.k8s.aws/resource" = "shared"
          }
          StringEquals = {
            "aws:ResourceTag/elbv2.k8s.aws/resource" = "shared"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:CreateRule"
        ]
        Resource = "arn:aws:elasticloadbalancing:*:*:listener-rule/app/*/*/*"
        Condition = {
          StringLike = {
            "aws:RequestTag/elbv2.k8s.aws/resource" = "shared"
          }
          StringEquals = {
            "aws:ResourceTag/elbv2.k8s.aws/resource" = "shared"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:CreateRule"
        ]
        Resource = "arn:aws:elasticloadbalancing:*:*:listener-rule/net/*/*/*"
        Condition = {
          StringLike = {
            "aws:RequestTag/elbv2.k8s.aws/resource" = "shared"
          }
          StringEquals = {
            "aws:ResourceTag/elbv2.k8s.aws/resource" = "shared"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:SetWebAcl",
          "elasticloadbalancing:ModifyListener"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:AddListenerCertificates",
          "elasticloadbalancing:RemoveListenerCertificates"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:ModifyRule"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(
    { "Name" = "${var.cluster_name}-aws-load-balancer-controller" },
    var.tags
  )
}

resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller" {
  count = var.enable_aws_load_balancer_controller ? 1 : 0

  role       = aws_iam_role.aws_load_balancer_controller[0].name
  policy_arn = aws_iam_policy.aws_load_balancer_controller[0].arn
}

#########################################
# AWS Load Balancer Controller Service Account
#########################################

resource "kubernetes_service_account" "aws_load_balancer_controller" {
  count = var.enable_aws_load_balancer_controller ? 1 : 0

  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    labels = {
      "app.kubernetes.io/name"       = "aws-load-balancer-controller"
      "app.kubernetes.io/managed-by" = "terraform"
    }
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.aws_load_balancer_controller[0].arn
    }
  }
}

#########################################
# AWS Load Balancer Controller RBAC
#########################################

resource "kubernetes_cluster_role" "aws_load_balancer_controller" {
  count = var.enable_aws_load_balancer_controller ? 1 : 0

  metadata {
    name = "aws-load-balancer-controller"
    labels = {
      "app.kubernetes.io/name"       = "aws-load-balancer-controller"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  rule {
    api_groups = [""]
    resources  = ["events"]
    verbs      = ["create", "patch"]
  }

  rule {
    api_groups = [""]
    resources  = ["endpoints"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = [""]
    resources  = ["nodes"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = [""]
    resources  = ["pods"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = [""]
    resources  = ["pods/status"]
    verbs      = ["patch", "update"]
  }

  rule {
    api_groups = [""]
    resources  = ["services"]
    verbs      = ["get", "list", "watch", "patch", "update"]
  }

  rule {
    api_groups = [""]
    resources  = ["services/status"]
    verbs      = ["patch", "update"]
  }

  rule {
    api_groups = ["extensions"]
    resources  = ["ingresses"]
    verbs      = ["get", "list", "watch", "update"]
  }

  rule {
    api_groups = ["extensions"]
    resources  = ["ingresses/status"]
    verbs      = ["update"]
  }

  rule {
    api_groups = ["networking.k8s.io"]
    resources  = ["ingresses"]
    verbs      = ["get", "list", "watch", "update"]
  }

  rule {
    api_groups = ["networking.k8s.io"]
    resources  = ["ingresses/status"]
    verbs      = ["update"]
  }

  rule {
    api_groups = ["networking.k8s.io"]
    resources  = ["ingressclasses"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["coordination.k8s.io"]
    resources  = ["leases"]
    verbs      = ["create", "delete", "get", "patch", "update"]
  }

  rule {
    api_groups = ["discovery.k8s.io"]
    resources  = ["endpointslices"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_cluster_role_binding" "aws_load_balancer_controller" {
  count = var.enable_aws_load_balancer_controller ? 1 : 0

  metadata {
    name = "aws-load-balancer-controller"
    labels = {
      "app.kubernetes.io/name"       = "aws-load-balancer-controller"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.aws_load_balancer_controller[0].metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.aws_load_balancer_controller[0].metadata[0].name
    namespace = kubernetes_service_account.aws_load_balancer_controller[0].metadata[0].namespace
  }
}
