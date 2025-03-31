##############################
# Fargate Profile
##############################

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "pod_execution_role_arn" {
  description = "IAM role ARN for Fargate pod execution"
  type        = string
}

variable "profiles" {
  description = "List of Fargate profile configurations"
  type = list(object({
    name       = string
    subnet_ids = list(string)
    tags       = optional(map(string), {})
    selectors = list(object({
      namespace = string
      labels    = optional(map(string))
    }))
  }))
}
