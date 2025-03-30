#########################################
# Locals: Raw Toggle Profiles
#########################################

locals {
  raw_toggle_profiles = [
    var.enable_default ? {
      name       = "default"
      subnet_ids = var.private_subnet_ids
      tags       = {}
      selectors  = [{ namespace = "default" }]
    } : null,

    var.enable_coredns ? {
      name       = "coredns"
      subnet_ids = var.private_subnet_ids
      tags       = {}
      selectors = [{
        namespace = "kube-system"
        labels    = { "k8s-app" = "kube-dns" }
      }]
    } : null,

    var.enable_metrics_server ? {
      name       = "metrics-server"
      subnet_ids = var.private_subnet_ids
      tags       = {}
      selectors = [{
        namespace = "kube-system"
        labels    = { "app.kubernetes.io/name" = "metrics-server" }
      }]
    } : null,

    var.enable_aws_observability ? {
      name       = "aws-observability"
      subnet_ids = var.private_subnet_ids
      tags       = {}
      selectors  = [{ namespace = "aws-observability" }]
    } : null
  ]
}

#########################################
# Locals: Processed Fargate Profiles
#########################################

locals {
  toggle_profiles = [
    for profile in local.raw_toggle_profiles : {
      name       = profile.name
      subnet_ids = profile.subnet_ids
      tags       = profile.tags
      selectors = [
        for s in profile.selectors : {
          namespace = s.namespace
          labels    = try(s.labels, {})
        }
      ]
    } if profile != null
  ]

  effective_profiles = concat(
    local.toggle_profiles,
    var.profiles != null ? var.profiles : []
  )
}

#########################################
# AWS EKS Fargate Profiles
#########################################

resource "aws_eks_fargate_profile" "this" {
  for_each = {
    for profile in local.effective_profiles :
    profile.name => profile
  }

  cluster_name           = var.cluster_name
  fargate_profile_name   = each.value.name
  pod_execution_role_arn = var.pod_execution_role_arn
  subnet_ids             = each.value.subnet_ids
  tags                   = each.value.tags

  dynamic "selector" {
    for_each = each.value.selectors
    content {
      namespace = selector.value.namespace
      labels    = lookup(selector.value, "labels", null)
    }
  }
}
