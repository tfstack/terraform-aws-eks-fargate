#########################################
# Addons
#########################################

output "eks_addons" {
  description = "Versions of enabled EKS addons"
  value       = module.addons.eks_addons
}

#########################################
# Cluster
#########################################

output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = module.cluster.cluster_name
}

output "cluster_version" {
  description = "The Kubernetes version used for the EKS cluster"
  value       = module.cluster.cluster_version
}

output "eks_cluster_endpoint" {
  description = "The endpoint URL of the EKS cluster"
  value       = module.cluster.eks_cluster_endpoint
}

output "eks_cluster_ca_cert" {
  description = "The base64-decoded certificate authority data for the EKS cluster"
  value       = module.cluster.eks_cluster_ca_cert
}

output "eks_cluster_auth_token" {
  description = "Authentication token for the EKS cluster (used by kubectl and SDKs)"
  value       = module.cluster.eks_cluster_auth_token
  sensitive   = true
}

output "eks_fargate_pod_execution_role_arn" {
  description = "ARN of the EKS Fargate Pod Execution IAM Role"
  value       = module.cluster.eks_fargate_pod_execution_role_arn
}

output "eks_fargate_pod_execution_role_name" {
  description = "Name of the EKS Fargate Pod Execution IAM Role"
  value       = module.cluster.eks_fargate_pod_execution_role_name
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN for the EKS cluster, used for IRSA"
  value       = module.cluster.oidc_provider_arn
}

output "oidc_provider_url" {
  description = "OIDC provider URL for the EKS cluster, used for IRSA"
  value       = module.cluster.oidc_provider_url
}

#########################################
# Fargate Profiles
#########################################

output "fargate_profile_names" {
  description = "List of Fargate profile names"
  value       = module.fargate_profiles.fargate_profile_names
}

output "fargate_profile_selectors" {
  description = "Map of Fargate profile name to its pod selectors"
  value       = module.fargate_profiles.fargate_profile_selectors
}

#########################################
# Namespaces
#########################################

output "namespace_names" {
  description = "List of created namespace names"
  value       = module.namespaces.namespace_names
}

output "namespace_labels" {
  description = "Labels applied to each namespace"
  value       = module.namespaces.namespace_labels
}

output "namespace_annotations" {
  description = "Annotations applied to each namespace"
  value       = module.namespaces.namespace_annotations
}

#########################################
# Workloads
#########################################

output "workload_deployment_names" {
  description = "Map of workload name to its Kubernetes Deployment name"
  value = {
    for k, m in module.workload :
    k => m.deployment_name
  }
}

output "workload_service_account_names" {
  description = "Map of workload name to its ServiceAccount name"
  value = {
    for k, m in module.workload :
    k => m.service_account_name
  }
}

output "workload_irsa_role_arns" {
  description = "Map of workload name to its IRSA role ARN (null if not created)"
  value = {
    for k, m in module.workload :
    k => m.irsa_role_arn
  }
}

output "workload_configmap_names" {
  description = "Map of workload name to list of ConfigMap names"
  value = {
    for k, m in module.workload :
    k => m.configmap_names
  }
}
