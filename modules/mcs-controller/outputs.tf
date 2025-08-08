output "controller_namespace" {
  description = "Namespace where the MCS controller is deployed"
  value       = try(kubernetes_namespace.mcs_controller[0].metadata[0].name, null)
}

output "controller_service_account_name" {
  description = "Service account name for the MCS controller"
  value       = try(kubernetes_service_account.mcs_controller[0].metadata[0].name, null)
}

output "controller_policy_arn" {
  description = "IAM policy ARN for the MCS controller CloudMap permissions"
  value       = try(aws_iam_policy.mcs_controller_cloudmap[0].arn, null)
}

output "controller_deployment_name" {
  description = "Name of the MCS controller deployment"
  value       = try(kubernetes_deployment.mcs_controller[0].metadata[0].name, null)
}
