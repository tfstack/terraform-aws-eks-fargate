#########################################
# Locals: Raw Namespace Definitions
#########################################

locals {
  raw_toggle_namespaces = [
    for ns in [
      var.enable_cloudwatch ? {
        name = "amazon-cloudwatch"
        labels = {
          "aws-observability" = "enabled"
        }
      } : null,

      var.enable_observability ? {
        name = "aws-observability"
        labels = {
          "aws-observability" = "enabled"
        }
        annotations = {
          "kubectl.kubernetes.io/last-applied-configuration" = jsonencode({
            apiVersion = "v1"
            kind       = "Namespace"
            metadata = {
              name = "aws-observability"
              labels = {
                "aws-observability" = "enabled"
              }
              annotations = {}
            }
          })
        }
      } : null
    ] : ns if ns != null
  ]
}

#########################################
# Locals: Processed Namespaces
#########################################

locals {
  toggle_namespaces = [
    for ns in local.raw_toggle_namespaces : {
      name        = ns.name
      labels      = try(ns.labels, {})
      annotations = try(ns.annotations, {})
    } if ns != null
  ]

  effective_namespaces = concat(
    local.toggle_namespaces,
    var.namespaces != null ? var.namespaces : []
  )
}

#########################################
# Kubernetes Namespaces Resources
#########################################

resource "kubernetes_namespace" "this" {
  for_each = {
    for ns in local.effective_namespaces : ns.name => ns
  }

  metadata {
    name        = each.value.name
    labels      = try(each.value.labels, {})
    annotations = try(each.value.annotations, {})
  }
}
