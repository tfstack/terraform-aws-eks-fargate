output "eks_addons" {
  description = "Map of EKS addon names to their resolved versions"
  value = {
    for addon in aws_eks_addon.this :
    addon.addon_name => addon.addon_version
  }
}
