#########################################
# EKS Cluster Outputs
#########################################

output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = aws_eks_cluster.this.name
}

output "cluster_version" {
  description = "The Kubernetes version used for the EKS cluster"
  value       = aws_eks_cluster.this.version
}

output "eks_cluster_endpoint" {
  description = "The endpoint URL of the EKS cluster"
  value       = aws_eks_cluster.this.endpoint
}

output "eks_cluster_ca_cert" {
  description = "The base64-decoded certificate authority data for the EKS cluster"
  value       = base64decode(aws_eks_cluster.this.certificate_authority[0].data)
}

output "eks_cluster_auth_token" {
  description = "Authentication token for the EKS cluster (used by kubectl and SDKs)"
  value       = data.aws_eks_cluster_auth.this.token
  sensitive   = true
}

output "eks_fargate_pod_execution_role_arn" {
  description = "ARN of the EKS Fargate Pod Execution IAM Role"
  value       = aws_iam_role.eks_fargate_pod.arn
}
