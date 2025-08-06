output "configmap_names" {
  description = "List of created ConfigMap names"
  value       = [for cm in kubernetes_config_map.this : cm.metadata[0].name]
}

output "service_name" {
  description = "Name of the created service"
  value       = var.create_service ? kubernetes_service.this[0].metadata[0].name : null
}

output "service_cluster_ip" {
  description = "Cluster IP of the created service"
  value       = var.create_service ? kubernetes_service.this[0].spec[0].cluster_ip : null
}

output "service_ports" {
  description = "Ports of the created service"
  value = var.create_service ? [for port in kubernetes_service.this[0].spec[0].port : {
    name        = port.name
    port        = port.port
    target_port = port.target_port
    protocol    = port.protocol
  }] : []
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
