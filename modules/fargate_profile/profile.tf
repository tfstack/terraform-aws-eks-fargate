#########################################
# Fargate Profile
#########################################

resource "aws_eks_fargate_profile" "this" {
  for_each = {
    for profile in var.profiles :
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
