#######################################
# Kubernetes Version
#######################################
data "aws_eks_cluster_versions" "available" {
  cluster_type   = "eks"
  version_status = "STANDARD_SUPPORT"
}

locals {
  latest_kubernetes_version = reverse(sort([
    for v in data.aws_eks_cluster_versions.available.cluster_versions : v.cluster_version
  ]))[0]

  kubernetes_version = (
    var.cluster_version == "latest"
    ? local.latest_kubernetes_version
    : var.cluster_version
  )
}

#######################################
# Logging and Monitoring (Add-ons)
#######################################
data "aws_eks_addon_version" "latest" {
  for_each = {
    for addon in var.eks_addons : addon.name => addon
    if contains(["", null, "latest"], addon.addon_version)
  }

  addon_name         = each.value.name
  kubernetes_version = local.kubernetes_version
  most_recent        = true
}

#######################################
# Access Control and Add-on Management
#######################################
resource "aws_eks_addon" "this" {
  for_each = { for addon in var.eks_addons : addon.name => addon }

  cluster_name = var.cluster_name
  addon_name   = each.value.name

  addon_version = (
    contains(["", null, "latest"], each.value.addon_version)
    ? data.aws_eks_addon_version.latest[each.key].version
    : each.value.addon_version
  )

  configuration_values        = each.value.configuration_values
  resolve_conflicts_on_create = each.value.resolve_conflicts_on_create
  resolve_conflicts_on_update = each.value.resolve_conflicts_on_update
  tags                        = each.value.tags
  preserve                    = each.value.preserve
}
