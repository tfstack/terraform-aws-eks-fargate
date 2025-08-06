output "controller_namespace" {
  description = "Namespace where the AWS Load Balancer Controller is deployed"
  value       = var.enabled ? "kube-system" : null
}

output "controller_service_account_name" {
  description = "Name of the AWS Load Balancer Controller service account"
  value       = var.enabled ? "aws-load-balancer-controller" : null
}

output "controller_role_arn" {
  description = "ARN of the IAM role for the AWS Load Balancer Controller"
  value       = var.enabled ? aws_iam_role.aws_load_balancer_controller[0].arn : null
}

output "controller_policy_arn" {
  description = "ARN of the IAM policy for the AWS Load Balancer Controller"
  value       = var.enabled ? aws_iam_policy.aws_load_balancer_controller[0].arn : null
}
