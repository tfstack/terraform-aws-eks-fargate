#########################################
# EKS Cluster Configuration
#########################################

variable "cluster_name" {
  type = string
}

variable "cluster_version" {
  type    = string
  default = "latest"
}

#########################################
# Addons Configuration
#########################################

variable "enable_addons" {
  type = object({
    vpc_cni        = bool
    coredns        = bool
    kube_proxy     = bool
    metrics_server = bool
    pod_identity   = bool
  })
}

variable "addon_versions" {
  type = map(string)
}

#########################################
# AWS Load Balancer Controller Variables
#########################################

variable "enable_aws_load_balancer_controller" {
  description = "Enable AWS Load Balancer Controller addon"
  type        = bool
  default     = false
}

variable "aws_load_balancer_controller_addon_version" {
  description = "Version of AWS Load Balancer Controller addon to use"
  type        = string
  default     = null
}

variable "oidc_provider_arn" {
  description = "ARN of the OIDC provider for the EKS cluster"
  type        = string
  default     = null
}

#########################################
# Common Tags
#########################################

variable "tags" {
  description = "A map of tags to use on all resources"
  type        = map(string)
  default     = {}
}
