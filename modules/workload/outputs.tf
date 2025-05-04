output "configmap_names" {
  description = "List of created ConfigMap names"
  value       = [for cm in kubernetes_config_map.this : cm.metadata[0].name]
}


output "deployment_name" {
  description = "Name of the Kubernetes deployment"
  value       = kubernetes_deployment.this.metadata[0].name
}

output "irsa_role_arn" {
  description = "IRSA role ARN if created"
  value       = try(aws_iam_role.irsa[0].arn, null)
}

output "service_account_name" {
  description = "Name of the Kubernetes service account used by the workload"
  value       = kubernetes_service_account.this.metadata[0].name
}
