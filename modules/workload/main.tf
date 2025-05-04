#########################################
# Locals
#########################################

locals {
  sa_name = var.service_account_name != null ? var.service_account_name : var.name

  configmap_hash = sha256(join("", [
    for cm in var.configmaps : join("", values(cm.data))
  ]))

  effective_namespace_labels      = try(var.namespace_metadata.labels, {})
  effective_namespace_annotations = try(var.namespace_metadata.annotations, {})
}

#########################################
# Kubernetes Namespace
#########################################

resource "kubernetes_namespace" "this" {
  count = var.create_namespace ? 1 : 0

  metadata {
    name        = var.namespace
    labels      = local.effective_namespace_labels
    annotations = local.effective_namespace_annotations
  }
}

#########################################
# IAM Role (IRSA)
#########################################

resource "aws_iam_role" "irsa" {
  count = var.irsa.enabled ? 1 : 0

  name = "${var.cluster_name}-${var.name}-irsa"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Federated = var.irsa.oidc_provider_arn
      },
      Action = "sts:AssumeRoleWithWebIdentity",
      Condition = {
        StringEquals = {
          "${replace(var.irsa.oidc_provider_arn, ":oidc-provider/", ":sub")}" = "system:serviceaccount:${var.namespace}:${local.sa_name}"
        }
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "this" {
  for_each = var.irsa.enabled ? toset(try(var.irsa.policy_arns, [])) : toset([])

  role       = aws_iam_role.irsa[0].name
  policy_arn = each.value
}

#########################################
# Kubernetes Service Account
#########################################

resource "kubernetes_service_account" "this" {
  metadata {
    name      = local.sa_name
    namespace = var.namespace

    annotations = var.irsa.enabled ? {
      "eks.amazonaws.com/role-arn" = aws_iam_role.irsa[0].arn
    } : {}
  }
}

#########################################
# Kubernetes ConfigMaps
#########################################

resource "kubernetes_config_map" "this" {
  for_each = { for cm in var.configmaps : cm.name => cm }

  metadata {
    name      = each.key
    namespace = var.namespace
  }

  data = each.value.data
}

resource "null_resource" "configmap_trigger" {
  triggers = {
    configmap_hash = local.configmap_hash
  }
}

#########################################
# Kubernetes Deployment
#########################################

resource "kubernetes_deployment" "this" {
  metadata {
    name      = var.name
    namespace = var.namespace
    labels    = merge({ app = var.name }, var.labels)

    annotations = merge(
      var.logging.enabled ? {
        "eks.amazonaws.com/enable-logging" = "true"
      } : {},
      try(var.logging.fargate_role_arn, null) != null ? {
        "eks.amazonaws.com/role-arn" = var.logging.fargate_role_arn
      } : {}
    )
  }

  spec {
    replicas = var.replicas

    selector {
      match_labels = {
        app = var.name
      }
    }

    template {
      metadata {
        labels = merge({
          app                      = var.name,
          "app.kubernetes.io/name" = var.name
        }, var.labels)
      }

      spec {
        service_account_name = local.sa_name

        node_selector = {
          "eks.amazonaws.com/compute-type" = "fargate"
        }

        toleration {
          key      = "eks.amazonaws.com/compute-type"
          operator = "Equal"
          value    = "fargate"
          effect   = "NoSchedule"
        }

        dynamic "init_container" {
          for_each = var.init_containers
          content {
            name    = init_container.value.name
            image   = init_container.value.image
            command = try(init_container.value.command, null)
            args    = try(init_container.value.args, null)

            dynamic "env" {
              for_each = coalesce(init_container.value.env, [])
              content {
                name  = env.value.name
                value = env.value.value
              }
            }

            dynamic "volume_mount" {
              for_each = coalesce(init_container.value.volume_mounts, [])
              content {
                name       = volume_mount.value.name
                mount_path = volume_mount.value.mount_path
              }
            }
          }
        }

        dynamic "container" {
          for_each = var.containers
          content {
            name    = container.value.name
            image   = container.value.image
            command = try(container.value.command, null)
            args    = try(container.value.args, null)

            dynamic "env" {
              for_each = coalesce(container.value.env, [])
              content {
                name  = env.value.name
                value = env.value.value
              }
            }

            dynamic "resources" {
              for_each = container.value.resources != null ? [container.value.resources] : []
              content {
                limits   = try(resources.value.limits, null)
                requests = try(resources.value.requests, null)
              }
            }

            dynamic "volume_mount" {
              for_each = coalesce(container.value.volume_mounts, [])
              content {
                name       = volume_mount.value.name
                mount_path = volume_mount.value.mount_path
              }
            }
          }
        }

        dynamic "volume" {
          for_each = var.volumes
          content {
            name = volume.value.name

            dynamic "config_map" {
              for_each = volume.value.config_map != null ? [volume.value.config_map] : []
              content {
                name = config_map.value.name
              }
            }

            dynamic "secret" {
              for_each = volume.value.secret != null ? [volume.value.secret] : []
              content {
                secret_name = secret.value.secret_name
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    null_resource.configmap_trigger,
    kubernetes_service_account.this
  ]
}
