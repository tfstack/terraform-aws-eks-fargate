#########################################
# CloudMap Controller for Single Cluster
# Service Discovery Integration
#########################################

#########################################
# Data Sources
#########################################

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

#########################################
# Local Values
#########################################

locals {
  controller_name = "cloudmap-controller"
  namespace_name  = "cloudmap-system"
}

#########################################
# Kubernetes Namespace
#########################################

resource "kubernetes_namespace" "cloudmap_system" {
  metadata {
    name = local.namespace_name
    labels = {
      "app.kubernetes.io/name"       = local.controller_name
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

#########################################
# IAM Role for CloudMap Service Account
#########################################

resource "aws_iam_role" "cloudmap_controller" {
  name = "${var.cluster_name}-cloudmap-controller"

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
            "${replace(var.oidc_provider_arn, "/^(.*provider/)/", "")}:sub" = "system:serviceaccount:${local.namespace_name}:${local.controller_name}"
            "${replace(var.oidc_provider_arn, "/^(.*provider/)/", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge(
    { "Name" = "${var.cluster_name}-cloudmap-controller" },
    var.tags
  )
}

#########################################
# IAM Policy for CloudMap Access
#########################################

resource "aws_iam_policy" "cloudmap_controller" {
  name        = "${var.cluster_name}-cloudmap-controller"
  description = "Policy for CloudMap service discovery controller"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "servicediscovery:CreateHttpNamespace",
          "servicediscovery:CreatePrivateDnsNamespace",
          "servicediscovery:CreatePublicDnsNamespace",
          "servicediscovery:CreateService",
          "servicediscovery:DeleteNamespace",
          "servicediscovery:DeleteService",
          "servicediscovery:DeregisterInstance",
          "servicediscovery:DiscoverInstances",
          "servicediscovery:GetInstance",
          "servicediscovery:GetInstancesHealthStatus",
          "servicediscovery:GetNamespace",
          "servicediscovery:GetOperation",
          "servicediscovery:GetService",
          "servicediscovery:ListInstances",
          "servicediscovery:ListNamespaces",
          "servicediscovery:ListOperations",
          "servicediscovery:ListServices",
          "servicediscovery:ListTagsForResource",
          "servicediscovery:RegisterInstance",
          "servicediscovery:TagResource",
          "servicediscovery:UntagResource",
          "servicediscovery:UpdateHttpNamespace",
          "servicediscovery:UpdateInstanceCustomHealthStatus",
          "servicediscovery:UpdatePrivateDnsNamespace",
          "servicediscovery:UpdatePublicDnsNamespace",
          "servicediscovery:UpdateService"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "route53:GetHealthCheck",
          "route53:CreateHealthCheck",
          "route53:UpdateHealthCheck",
          "route53:ChangeResourceRecordSets",
          "route53:DeleteHealthCheck"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(
    { "Name" = "${var.cluster_name}-cloudmap-controller" },
    var.tags
  )
}

resource "aws_iam_role_policy_attachment" "cloudmap_controller" {
  role       = aws_iam_role.cloudmap_controller.name
  policy_arn = aws_iam_policy.cloudmap_controller.arn
}

#########################################
# Kubernetes Service Account
#########################################

resource "kubernetes_service_account" "cloudmap_controller" {
  metadata {
    name      = local.controller_name
    namespace = kubernetes_namespace.cloudmap_system.metadata[0].name
    labels = {
      "app.kubernetes.io/name"       = local.controller_name
      "app.kubernetes.io/managed-by" = "terraform"
    }
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.cloudmap_controller.arn
    }
  }
}

#########################################
# RBAC Configuration
#########################################

resource "kubernetes_cluster_role" "cloudmap_controller" {
  metadata {
    name = "${var.cluster_name}-cloudmap-controller"
    labels = {
      "app.kubernetes.io/name"       = local.controller_name
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  rule {
    api_groups = [""]
    resources  = ["services", "endpoints", "pods"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = [""]
    resources  = ["events"]
    verbs      = ["create", "patch"]
  }

  rule {
    api_groups = [""]
    resources  = ["services/status"]
    verbs      = ["update"]
  }

  rule {
    api_groups = ["discovery.k8s.io"]
    resources  = ["endpointslices"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_cluster_role_binding" "cloudmap_controller" {
  metadata {
    name = "${var.cluster_name}-cloudmap-controller"
    labels = {
      "app.kubernetes.io/name"       = local.controller_name
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.cloudmap_controller.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.cloudmap_controller.metadata[0].name
    namespace = kubernetes_namespace.cloudmap_system.metadata[0].name
  }
}

#########################################
# ConfigMap for Controller Configuration
#########################################

resource "kubernetes_config_map" "cloudmap_controller" {
  metadata {
    name      = "${local.controller_name}-config"
    namespace = kubernetes_namespace.cloudmap_system.metadata[0].name
    labels = {
      "app.kubernetes.io/name"       = local.controller_name
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  data = {
    "config.yaml" = yamlencode({
      cluster = {
        name   = var.cluster_name
        region = data.aws_region.current.region
      }
      cloudmap = {
        namespace = var.cloudmap_namespace_name
        vpc_id    = var.vpc_id
      }
      controller = {
        sync_period = "30s"
        log_level   = "info"
      }
    })
  }
}

#########################################
# CloudMap Controller Deployment
#########################################

resource "kubernetes_cron_job_v1" "cloudmap_sync" {
  metadata {
    name      = "${local.controller_name}-sync"
    namespace = kubernetes_namespace.cloudmap_system.metadata[0].name
    labels = {
      "app.kubernetes.io/name"       = local.controller_name
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/component"  = "sync-job"
    }
  }

  spec {
    schedule                      = "*/2 * * * *" # Every 2 minutes
    concurrency_policy            = "Forbid"
    successful_jobs_history_limit = 3
    failed_jobs_history_limit     = 1

    job_template {
      metadata {
        labels = {
          "app.kubernetes.io/name"      = local.controller_name
          "app.kubernetes.io/component" = "sync-job"
        }
      }
      spec {
        template {
          metadata {
            labels = {
              "app.kubernetes.io/name"      = local.controller_name
              "app.kubernetes.io/component" = "sync-job"
            }
          }

          spec {
            service_account_name = kubernetes_service_account.cloudmap_controller.metadata[0].name
            restart_policy       = "OnFailure"

            container {
              name  = "cloudmap-sync"
              image = "amazon/aws-cli:2.13.25"

              command = ["/bin/sh"]
              args = ["-c", <<-EOT
                echo "Starting CloudMap service sync..."

                # Install kubectl
                curl -LO "https://dl.k8s.io/release/$$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
                chmod +x kubectl

                # Install jq for JSON processing
                yum install -y jq

                # Get services with cloudmap annotation
                ./kubectl get services --all-namespaces -o json | jq -r '
                  .items[] |
                  select(.metadata.annotations["service.cloudmap/register"] == "true") |
                  "\(.metadata.namespace):\(.metadata.name):\(.spec.clusterIP // "none"):\(.spec.ports[0].port // "80")"
                ' | while IFS=: read -r namespace service_name cluster_ip port; do

                  if [ "$$cluster_ip" != "none" ] && [ "$$cluster_ip" != "None" ]; then
                    echo "Registering service: $$service_name in namespace: $$namespace"

                    # Get namespace ID
                    NAMESPACE_ID=$$(aws servicediscovery list-namespaces --region $$AWS_REGION --query "Namespaces[?Name=='$$CLOUDMAP_NAMESPACE'].Id" --output text)

                    if [ -n "$$NAMESPACE_ID" ] && [ "$$NAMESPACE_ID" != "None" ]; then
                      # Check if service exists
                      SERVICE_ID=$$(aws servicediscovery list-services --region $$AWS_REGION --filters Name=NAMESPACE_ID,Values=$$NAMESPACE_ID --query "Services[?Name=='$$service_name'].Id" --output text)

                      if [ -z "$$SERVICE_ID" ] || [ "$$SERVICE_ID" = "None" ]; then
                        echo "Creating service: $$service_name"
                        # Create service if it doesn't exist
                        SERVICE_ID=$$(aws servicediscovery create-service \
                          --region $$AWS_REGION \
                          --name "$$service_name" \
                          --namespace-id "$$NAMESPACE_ID" \
                          --dns-config "NamespaceId=$$NAMESPACE_ID,RoutingPolicy=MULTIVALUE,DnsRecords=[{Type=A,TTL=10}]" \
                          --health-check-custom-config "FailureThreshold=1" \
                          --query 'Service.Id' --output text)
                      fi

                      if [ -n "$$SERVICE_ID" ] && [ "$$SERVICE_ID" != "None" ]; then
                        # Register instance
                        INSTANCE_ID="$$service_name-$$namespace-$$(date +%s)"
                        echo "Registering instance: $$INSTANCE_ID with IP: $$cluster_ip"

                        aws servicediscovery register-instance \
                          --region $$AWS_REGION \
                          --service-id "$$SERVICE_ID" \
                          --instance-id "$$INSTANCE_ID" \
                          --attributes "AWS_INSTANCE_IPV4=$$cluster_ip,AWS_INSTANCE_PORT=$$port,NAMESPACE=$$namespace,SERVICE=$$service_name" \
                          --no-cli-pager
                      fi
                    fi
                  fi
                done

                echo "CloudMap service sync completed."
              EOT
              ]

              env {
                name  = "AWS_REGION"
                value = data.aws_region.current.region
              }

              env {
                name  = "CLUSTER_NAME"
                value = var.cluster_name
              }

              env {
                name  = "CLOUDMAP_NAMESPACE"
                value = var.cloudmap_namespace_name
              }

              env {
                name  = "VPC_ID"
                value = var.vpc_id
              }

              resources {
                limits = {
                  cpu    = "200m"
                  memory = "256Mi"
                }
                requests = {
                  cpu    = "100m"
                  memory = "128Mi"
                }
              }
            }

            # Ensure pods run on Fargate
            toleration {
              key      = "eks.amazonaws.com/compute-type"
              operator = "Equal"
              value    = "fargate"
              effect   = "NoSchedule"
            }
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_service_account.cloudmap_controller,
    aws_iam_role_policy_attachment.cloudmap_controller
  ]
}

#########################################
# Service for CloudMap Controller
#########################################

resource "kubernetes_service" "cloudmap_controller" {
  metadata {
    name      = local.controller_name
    namespace = kubernetes_namespace.cloudmap_system.metadata[0].name
    labels = {
      "app.kubernetes.io/name"       = local.controller_name
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  spec {
    selector = {
      "app.kubernetes.io/name" = local.controller_name
    }

    port {
      name        = "webhook-server"
      port        = 9443
      target_port = 9443
      protocol    = "TCP"
    }

    port {
      name        = "metrics"
      port        = 8080
      target_port = 8080
      protocol    = "TCP"
    }

    port {
      name        = "health"
      port        = 8081
      target_port = 8081
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }
}

#########################################
# AWS Load Balancer Controller Annotations
# for CloudMap Service Discovery
#########################################

resource "kubernetes_config_map" "cloudmap_annotations" {
  count = var.enable_load_balancer_controller ? 1 : 0

  metadata {
    name      = "cloudmap-annotations"
    namespace = kubernetes_namespace.cloudmap_system.metadata[0].name
    labels = {
      "app.kubernetes.io/name"       = local.controller_name
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  data = {
    "annotations.yaml" = yamlencode({
      annotations = {
        "service.beta.kubernetes.io/aws-load-balancer-type"                              = "external"
        "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type"                   = "ip"
        "service.beta.kubernetes.io/aws-load-balancer-scheme"                            = "internal"
        "service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled" = "true"
        "external-dns.alpha.kubernetes.io/hostname"                                      = "${var.cluster_name}.${var.cloudmap_namespace_name}"
      }
    })
  }
}
