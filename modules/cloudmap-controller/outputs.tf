#########################################
# CloudMap Controller Outputs
#########################################

output "controller_namespace" {
  description = "Namespace where the CloudMap controller is deployed"
  value       = kubernetes_namespace.cloudmap_system.metadata[0].name
}

output "controller_service_account_name" {
  description = "Name of the CloudMap controller service account"
  value       = kubernetes_service_account.cloudmap_controller.metadata[0].name
}

output "controller_role_arn" {
  description = "ARN of the IAM role for the CloudMap controller"
  value       = aws_iam_role.cloudmap_controller.arn
}

output "controller_policy_arn" {
  description = "ARN of the IAM policy for the CloudMap controller"
  value       = aws_iam_policy.cloudmap_controller.arn
}

output "config_map_name" {
  description = "Name of the ConfigMap containing controller configuration"
  value       = kubernetes_config_map.cloudmap_controller.metadata[0].name
}
