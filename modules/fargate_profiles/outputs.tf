output "fargate_profile_names" {
  description = "Names of the created Fargate profiles"
  value       = [for fp in aws_eks_fargate_profile.this : fp.fargate_profile_name]
}

output "fargate_profile_selectors" {
  description = "Map of Fargate profile name to its pod selectors"
  value = {
    for name, fp in aws_eks_fargate_profile.this :
    name => fp.selector
  }
}
