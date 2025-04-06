# eks-fargate/main.tf

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

#########################################
# Module: EKS Cluster
#########################################

module "cluster" {
  source = "./modules/cluster"

  cluster_name                  = var.cluster_name
  cluster_version               = var.cluster_version
  tags                          = var.tags
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
    module.fp_cloudwatch,
    kubernetes_namespace.amazon_cloudwatch,
    kubernetes_service_account.cloudwatch_agent,
    aws_iam_role_policy_attachment.cloudwatch_irsa_policy
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

resource "aws_iam_role" "fluentbit_irsa" {
  name = "${var.cluster_name}-fluentbit-irsa"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Federated = module.cluster.oidc_provider_arn
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          StringEquals = {
            "${replace(module.cluster.oidc_provider_arn, ":oidc-provider/", ":sub")}" = "system:serviceaccount:amazon-cloudwatch:${var.fluentbit_sa_name}"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "fluentbit_cloudwatch" {
  role       = aws_iam_role.fluentbit_irsa.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "kubernetes_service_account" "fluentbit" {
  metadata {
    name      = var.fluentbit_sa_name
    namespace = "amazon-cloudwatch"

    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.fluentbit_irsa.arn
    }
  }

  depends_on = [
    kubernetes_namespace.amazon_cloudwatch
  ]
}

resource "kubernetes_config_map" "fluentbit_config" {
  metadata {
    name      = "fluent-bit-config"
    namespace = "amazon-cloudwatch"
  }

  data = {
    "fluent-bit.conf" = <<-EOT
      [SERVICE]
          Flush        1
          Daemon       Off
          Log_Level    info
          Parsers_File parsers.conf

      [INPUT]
          Name              forward
          Listen            0.0.0.0
          Port              24224

      [OUTPUT]
          Name              cloudwatch_logs
          Match             *
          region            ap-southeast-1
          log_group_name    /aws/eks/${var.cluster_name}/fluent-bit
          log_stream_prefix fargate-
          auto_create_group false
    EOT

    "parsers.conf" = <<-EOT
      [PARSER]
          Name   json
          Format json
    EOT
  }
}

resource "kubernetes_deployment" "fluentbit" {
  metadata {
    name      = "fluent-bit"
    namespace = "amazon-cloudwatch"
    labels = {
      app = "fluent-bit"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "fluent-bit"
      }
    }

    template {
      metadata {
        labels = {
          app                      = "fluent-bit"
          "app.kubernetes.io/name" = "amazon-cloudwatch-observability"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.fluentbit.metadata[0].name

        container {
          name    = "fluent-bit"
          image   = "public.ecr.aws/aws-observability/aws-for-fluent-bit:latest"
          command = ["/fluent-bit/bin/fluent-bit"]
          args    = ["-c", "/fluent-bit/etc/fluent-bit.conf"]

          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
          }

          volume_mount {
            name       = "config"
            mount_path = "/fluent-bit/etc/"
          }
        }

        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map.fluentbit_config.metadata[0].name
          }
        }
      }
    }
  }

  lifecycle {
    replace_triggered_by = [kubernetes_config_map.fluentbit_config]
  }

  depends_on = [
    kubernetes_config_map.fluentbit_config,
    kubernetes_service_account.fluentbit
  ]
}
