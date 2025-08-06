#########################################
# CloudMap Controller Variables
#########################################

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the EKS cluster is deployed"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the OIDC provider for the EKS cluster"
  type        = string
}

variable "cloudmap_namespace_name" {
  description = "Name of the CloudMap namespace"
  type        = string
}

variable "enable_load_balancer_controller" {
  description = "Whether to enable AWS Load Balancer Controller integration"
  type        = bool
  default     = false
}

variable "tags" {
  description = "A map of tags to use on all resources"
  type        = map(string)
  default     = {}
}
