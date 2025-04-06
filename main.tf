# eks-fargate/main.tf

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

#########################################
# Locals
#########################################


locals {
  # default_fargate_profile = tolist([
  #   {
  #     name       = "default"
  #     subnet_ids = var.cluster_vpc_config.private_subnet_ids
  #     selectors = tolist([
  #       { namespace = "default", labels = null },
  #       { namespace = "kube-system", labels = null }
  #     ])
  #     tags = merge(
  #       { "Name" = "${var.cluster_name}-default" },
  #       var.tags
  #     )
  #   },
  #   {
  #     name       = "coredns"
  #     subnet_ids = var.cluster_vpc_config.private_subnet_ids
  #     selectors = tolist([
  #       {
  #         namespace = "kube-system"
  #         labels = {
  #           "k8s-app" = "kube-dns"
  #         }
  #       }
  #     ])

  #     tags = merge(
  #       { "Name" = "${var.cluster_name}-coredns" },
  #       var.tags
  #     )
  #   }
  # ])

  default_eks_addons = tolist([
    # {
    #   name          = "kube-proxy"
    #   addon_version = "latest"
    # },
    # {
    #   name          = "vpc-cni"
    #   addon_version = "latest"
    # },
    # {
    #   name          = "coredns"
    #   addon_version = "latest"
    #   configuration_values = jsonencode({
    #     tolerations = [{
    #       key      = "CriticalAddonsOnly"
    #       operator = "Exists"
    #     }]
    #     nodeSelector = {
    #       "eks.amazonaws.com/compute-type" = "fargate"
    #     }
    #   })
    #   resolve_conflicts_on_create = "OVERWRITE"
    #   resolve_conflicts_on_update = "OVERWRITE"
    # },
    # {
    #   name          = "metrics-server"
    #   addon_version = "latest"
    #   configuration_values = jsonencode({
    #     tolerations = [{
    #       key      = "CriticalAddonsOnly"
    #       operator = "Exists"
    #     }]
    #     nodeSelector = {
    #       "eks.amazonaws.com/compute-type" = "fargate"
    #     }
    #   })
    #   resolve_conflicts_on_create = "OVERWRITE"
    #   resolve_conflicts_on_update = "OVERWRITE"
    # }
  ])

  # Map of user overrides
  eks_addons_map = {
    for addon in var.eks_addons : addon.name => addon
  }

  # Schema default to normalize object shape
  addon_schema_defaults = {
    addon_version               = null
    configuration_values        = null
    resolve_conflicts_on_create = null
    resolve_conflicts_on_update = null
    preserve                    = null
    tags                        = null
  }

  resolved_eks_addons = (var.enable_eks_addons
    ? concat(
      [
        for default in local.default_eks_addons :
        merge(
          local.addon_schema_defaults,
          default,
          lookup(local.eks_addons_map, default.name, {})
        )
      ],
      [
        for name, addon in local.eks_addons_map :
        merge(local.addon_schema_defaults, addon)
        if !contains([for d in local.default_eks_addons : d.name], name)
      ]
    )
    : [
      for addon in var.eks_addons :
      merge(local.addon_schema_defaults, addon)
  ])
}

#########################################
# Module: EKS Cluster
#########################################

module "cluster" {
  source = "./modules/cluster"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version
  tags            = var.tags
  # eks_auto_node_role_arn        = module.cluster.eks_auto_node_role_arn
  vpc_id                        = var.vpc_id
  cluster_vpc_config            = var.cluster_vpc_config
  cluster_enabled_log_types     = var.cluster_enabled_log_types
  enable_cluster_encryption     = var.enable_cluster_encryption
  enable_elastic_load_balancing = var.enable_elastic_load_balancing
  enable_oidc                   = var.enable_oidc
  eks_log_prevent_destroy       = var.eks_log_prevent_destroy
  eks_log_retention_days        = var.eks_log_retention_days
}

resource "kubernetes_namespace" "amazon_cloudwatch" {
  count = var.enable_cloudwatch_observability_addon ? 1 : 0

  metadata {
    name = "amazon-cloudwatch"
    labels = {
      "aws-observability" = "enabled"
    }
  }

  depends_on = [
    module.cluster
  ]
}

module "fp_default" {
  count = var.enable_default_fargate_profile ? 1 : 0

  source = "./modules/fargate_profile"

  cluster_name           = var.cluster_name
  pod_execution_role_arn = module.cluster.eks_fargate_pod_execution_role_arn
  profiles = [
    {
      name                   = "default"
      subnet_ids             = var.cluster_vpc_config.private_subnet_ids
      pod_execution_role_arn = module.cluster.eks_fargate_pod_execution_role_arn

      selectors = [
        { namespace = "default" }
      ]
    },
  ]

  depends_on = [
    module.cluster
  ]
}

module "fp_coredns" {
  count = var.enable_coredns_addon ? 1 : 0

  source = "./modules/fargate_profile"

  cluster_name           = var.cluster_name
  pod_execution_role_arn = module.cluster.eks_fargate_pod_execution_role_arn
  profiles = [
    {
      name                   = "coredns"
      subnet_ids             = var.cluster_vpc_config.private_subnet_ids
      pod_execution_role_arn = module.cluster.eks_fargate_pod_execution_role_arn

      selectors = [
        {
          namespace = "kube-system"
          labels = {
            "k8s-app" = "kube-dns"
          }
        }
      ]
    },
  ]

  depends_on = [
    module.cluster
  ]
}

module "fp_metrics_server" {
  count = var.enable_metrics_server_addon ? 1 : 0

  source = "./modules/fargate_profile"

  cluster_name           = var.cluster_name
  pod_execution_role_arn = module.cluster.eks_fargate_pod_execution_role_arn
  profiles = [
    {
      name                   = "metrics-server"
      subnet_ids             = var.cluster_vpc_config.private_subnet_ids
      pod_execution_role_arn = module.cluster.eks_fargate_pod_execution_role_arn

      selectors = [
        {
          namespace = "kube-system"
          labels = {
            "app.kubernetes.io/name" = "metrics-server"
          }
        }
      ]
    },
  ]

  depends_on = [
    module.cluster
  ]
}

module "fp_cloudwatch" {
  count = var.enable_cloudwatch_observability_addon ? 1 : 0

  source = "./modules/fargate_profile"

  cluster_name           = var.cluster_name
  pod_execution_role_arn = module.cluster.eks_fargate_pod_execution_role_arn
  profiles = [
    {
      name       = "cloudwatch-observability"
      subnet_ids = var.cluster_vpc_config.private_subnet_ids

      selectors = [
        {
          namespace = "amazon-cloudwatch"
          labels = {
            "app.kubernetes.io/name" = "amazon-cloudwatch-observability"
          }
        }
      ]
    }
  ]

  depends_on = [
    kubernetes_namespace.amazon_cloudwatch
  ]
}

module "addon_coredns" {
  count = var.enable_coredns_addon ? 1 : 0

  source = "./modules/addons"

  cluster_name = var.cluster_name
  eks_addons = [
    {
      name          = "coredns"
      addon_version = var.coredns_addon_version
    },
  ]

  depends_on = [
    module.fp_coredns
  ]
}

module "addon_kube_proxy" {
  count = var.enable_kube_proxy_addon ? 1 : 0

  source = "./modules/addons"

  cluster_name = var.cluster_name
  eks_addons = [
    {
      name          = "kube-proxy"
      addon_version = var.kube_proxy_addon_version
    },
  ]

  depends_on = [
    module.cluster
  ]
}

module "addon_vpc_cni" {
  count = var.enable_vpc_cni_addon ? 1 : 0

  source = "./modules/addons"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  eks_addons = [
    {
      name                        = "vpc-cni"
      addon_version               = var.vpc_cni_addon_version
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "OVERWRITE"
      preserve                    = false
      tags = merge(
        {
          "Name" = "${var.cluster_name}-vpc-cni"
        },
        var.tags
      )
    }
  ]

  depends_on = [
    module.cluster
  ]
}

module "addon_metrics_server" {
  count = var.enable_metrics_server_addon ? 1 : 0

  source = "./modules/addons"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  eks_addons = [
    {
      name          = "metrics-server"
      addon_version = var.metrics_server_addon_version

      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "OVERWRITE"
      preserve                    = false
      tags = merge(
        {
          "Name" = "${var.cluster_name}-metrics-server"
        },
        var.tags
      )
    },
  ]

  depends_on = [
    module.fp_metrics_server
  ]
}

resource "aws_iam_role" "cloudwatch_irsa" {
  count = var.enable_cloudwatch_observability_addon ? 1 : 0

  name = "${var.cluster_name}-cloudwatch-agent-irsa"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "eks.amazonaws.com"
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          StringEquals = {
            "${replace(module.cluster.oidc_provider_arn, ":oidc-provider/", ":sub")}" : "system:serviceaccount:amazon-cloudwatch:cloudwatch-agent"
          }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "cloudwatch_irsa_policy" {
  count      = var.enable_cloudwatch_observability_addon ? 1 : 0
  role       = aws_iam_role.cloudwatch_irsa[0].name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "kubernetes_service_account" "cloudwatch_agent" {
  count = var.enable_cloudwatch_observability_addon ? 1 : 0

  metadata {
    name      = "cloudwatch-agent"
    namespace = "amazon-cloudwatch"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.cloudwatch_irsa[0].arn
    }
  }

  depends_on = [
    kubernetes_namespace.amazon_cloudwatch
  ]
}

module "addon_cloudwatch_observability" {
  count = var.enable_cloudwatch_observability_addon ? 1 : 0

  source = "./modules/addons"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  eks_addons = [
    {
      name          = "amazon-cloudwatch-observability"
      addon_version = var.cloudwatch_observability_addon_version
    }
  ]

  depends_on = [
    kubernetes_namespace.amazon_cloudwatch
  ]
}

module "addon_pod_identity_agent" {
  count = var.enable_pod_identity_agent_addon ? 1 : 0

  source = "./modules/addons"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  eks_addons = [
    {
      name          = "eks-pod-identity-agent"
      addon_version = var.pod_identity_agent_addon_version
    }
  ]

  depends_on = [
    module.cluster
  ]
}

module "helm_charts" {
  source = "./modules/helm_release"

  helm_charts = [
    {
      name       = "fluent-bit"
      namespace  = "amazon-cloudwatch"
      repository = "https://aws.github.io/eks-charts"
      chart      = "aws-for-fluent-bit"
      set_values = [
        { name = "cloudWatch.enabled", value = "true" },
        { name = "cloudWatch.region", value = "ap-southeast-1" }
      ]
    }
  ]
}
