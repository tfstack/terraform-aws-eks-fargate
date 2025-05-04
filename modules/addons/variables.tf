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
# Common Tags
#########################################

variable "tags" {
  description = "A map of tags to use on all resources"
  type        = map(string)
  default     = {}
}
