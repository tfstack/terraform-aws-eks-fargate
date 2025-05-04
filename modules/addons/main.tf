#########################################
# Data Sources
#########################################

data "aws_eks_cluster_versions" "available" {}

data "aws_eks_addon_version" "latest" {
  for_each = {
    for a in local.addons : a.name => a
    if contains(["", null, "latest"], a.version)
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
    }
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
