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
# CoreDNS Corefile (optional override)
#########################################

variable "enable_coredns_multicluster" {
  description = "If true and CoreDNS addon is enabled, manage the CoreDNS ConfigMap to include the multicluster plugin."
  type        = bool
  default     = false
}

variable "coredns_corefile" {
  description = "Optional CoreDNS Corefile content. If null and multicluster is enabled, a sensible default with 'multicluster clusterset.local' will be applied."
  type        = string
  default     = null
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
