#########################################
# Core Cluster Configuration
#########################################

variable "cluster_name" {
  type = string
}

variable "pod_execution_role_arn" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

#########################################
# Fargate Profiles (Toggle-based)
#########################################

variable "enable_default" {
  type    = bool
  default = true
}

variable "enable_coredns" {
  type    = bool
  default = false
}

variable "enable_aws_observability" {
  type    = bool
  default = false
}

variable "enable_metrics_server" {
  type    = bool
  default = false
}

#########################################
# Explicit Fargate Profiles
#########################################

variable "profiles" {
  description = "Explicit list of Fargate profile configurations"
  type = list(object({
    name       = string
    subnet_ids = list(string)
    tags       = optional(map(string), {})
    selectors = list(object({
      namespace = string
      labels    = optional(map(string))
    }))
  }))
  default = null
}
