data "aws_region" "current" {}

#########################################
# MCS Controller Module
#########################################

# Namespace
resource "kubernetes_namespace" "mcs_controller" {
  count = var.enabled ? 1 : 0

  metadata {
    name = "cloud-map-mcs-system"
    labels = {
      "control-plane" = "controller-manager"
    }
  }
}

# (CRDs and ClusterProperty resources are intentionally not managed here; the example handles them.)

# Service Account (IRSA)
resource "kubernetes_service_account" "mcs_controller" {
  count = var.enabled ? 1 : 0

  metadata {
    name      = "cloud-map-mcs-controller-manager"
    namespace = kubernetes_namespace.mcs_controller[0].metadata[0].name
    labels = {
      "control-plane" = "controller-manager"
    }
  }
}



# ClusterRole
resource "kubernetes_cluster_role" "mcs_controller" {
  count = var.enabled ? 1 : 0

  metadata {
    name = "cloud-map-mcs-controller-manager-role"
    labels = {
      "control-plane" = "controller-manager"
    }
  }

  rule {
    api_groups = [""]
    resources  = ["services", "endpoints", "secrets", "namespaces"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  rule {
    api_groups = ["multicluster.x-k8s.io"]
    resources  = ["serviceexports", "serviceimports"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  # Allow status updates on ServiceExport/ServiceImport
  rule {
    api_groups = ["multicluster.x-k8s.io"]
    resources  = ["serviceexports/status", "serviceimports/status"]
    verbs      = ["get", "update", "patch"]
  }

  rule {
    api_groups = ["coordination.k8s.io"]
    resources  = ["leases"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  rule {
    api_groups = [""]
    resources  = ["events"]
    verbs      = ["create", "patch"]
  }

  rule {
    api_groups = ["admissionregistration.k8s.io"]
    resources  = ["validatingwebhookconfigurations"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  # Needed by controller to read cluster identity and EndpointSlices
  rule {
    api_groups = ["about.k8s.io"]
    resources  = ["clusterproperties"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["discovery.k8s.io"]
    resources  = ["endpointslices"]
    verbs      = ["get", "list", "watch"]
  }
}

# ClusterRoleBinding
resource "kubernetes_cluster_role_binding" "mcs_controller" {
  count = var.enabled ? 1 : 0

  metadata {
    name = "cloud-map-mcs-controller-manager-rolebinding"
    labels = {
      "control-plane" = "controller-manager"
    }
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.mcs_controller[0].metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.mcs_controller[0].metadata[0].name
    namespace = kubernetes_namespace.mcs_controller[0].metadata[0].name
  }
}

# CloudMap Policy for Fargate Execution Role
resource "aws_iam_policy" "mcs_controller_cloudmap" {
  count = var.enabled ? 1 : 0

  name = "${var.cluster_name}-mcs-controller-cloudmap-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "servicediscovery:CreateService",
          "servicediscovery:DeleteService",
          "servicediscovery:GetService",
          "servicediscovery:ListServices",
          "servicediscovery:UpdateService",
          "servicediscovery:CreateHttpNamespace",
          "servicediscovery:CreatePrivateDnsNamespace",
          "servicediscovery:GetNamespace",
          "servicediscovery:ListNamespaces",
          "servicediscovery:GetInstance",
          "servicediscovery:RegisterInstance",
          "servicediscovery:DeregisterInstance",
          "servicediscovery:ListInstances",
          "servicediscovery:UpdateInstanceCustomHealthStatus"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach policy to Fargate execution role
resource "aws_iam_role_policy_attachment" "mcs_controller_cloudmap" {
  count = var.enabled ? 1 : 0

  role       = var.fargate_execution_role_name
  policy_arn = aws_iam_policy.mcs_controller_cloudmap[0].arn
}

# Region config for controller
resource "kubernetes_config_map" "mcs_aws_config" {
  count = var.enabled ? 1 : 0

  metadata {
    name      = "cloud-map-mcs-aws-config"
    namespace = kubernetes_namespace.mcs_controller[0].metadata[0].name
  }

  data = {
    AWS_REGION = data.aws_region.current.region
  }
}

# Deployment
resource "kubernetes_deployment" "mcs_controller" {
  count = var.enabled ? 1 : 0

  metadata {
    name      = "cloud-map-mcs-controller-manager"
    namespace = kubernetes_namespace.mcs_controller[0].metadata[0].name
    labels = {
      "control-plane" = "controller-manager"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        "control-plane" = "controller-manager"
      }
    }

    template {
      metadata {
        labels = {
          "control-plane" = "controller-manager"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.mcs_controller[0].metadata[0].name

        node_selector = {
          "eks.amazonaws.com/compute-type" = "fargate"
        }

        toleration {
          key      = "eks.amazonaws.com/compute-type"
          operator = "Equal"
          value    = "fargate"
          effect   = "NoSchedule"
        }

        security_context {
          run_as_non_root = true
        }

        container {
          name    = "manager"
          image   = "ghcr.io/aws/aws-cloud-map-mcs-controller-for-k8s:${var.controller_version}"
          command = ["/manager"]
          args    = ["--health-probe-bind-address=:8081", "--metrics-bind-address=127.0.0.1:8080", "--leader-elect"]

          resources {
            limits   = { cpu = "100m", memory = "30Mi" }
            requests = { cpu = "100m", memory = "20Mi" }
          }

          liveness_probe {
            http_get {
              path   = "/healthz"
              port   = 8081
              scheme = "HTTP"
            }
            initial_delay_seconds = 15
            timeout_seconds       = 1
            period_seconds        = 20
            success_threshold     = 1
            failure_threshold     = 3
          }

          readiness_probe {
            http_get {
              path   = "/readyz"
              port   = 8081
              scheme = "HTTP"
            }
            initial_delay_seconds = 5
            timeout_seconds       = 1
            period_seconds        = 10
            success_threshold     = 1
            failure_threshold     = 3
          }

          env {
            name = "AWS_REGION"
            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.mcs_aws_config[0].metadata[0].name
                key  = "AWS_REGION"
              }
            }
          }



          security_context {
            allow_privilege_escalation = false
          }
        }

        container {
          name  = "kube-rbac-proxy"
          image = "gcr.io/kubebuilder/kube-rbac-proxy:v0.8.0"
          args = [
            "--secure-listen-address=0.0.0.0:8443",
            "--upstream=http://127.0.0.1:8080/",
            "--logtostderr=true",
            "--v=10"
          ]

          port {
            name           = "https"
            container_port = 8443
            protocol       = "TCP"
          }

          resources {
            limits   = { cpu = "50m", memory = "20Mi" }
            requests = { cpu = "25m", memory = "10Mi" }
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_cluster_role_binding.mcs_controller[0],
    kubernetes_config_map.mcs_aws_config[0]
  ]
}
