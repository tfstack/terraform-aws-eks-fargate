#########################################
# MCS Controller Variables
#########################################

variable "enabled" {
  description = "Enable MCS controller"
  type        = bool
  default     = false
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the OIDC provider"
  type        = string

  validation {
    condition     = var.enabled ? (length(coalesce(var.oidc_provider_arn, "")) > 0) : true
    error_message = "MCS controller requires IRSA. Enable OIDC on the cluster and pass a non-null oidc_provider_arn (set enable_oidc = true in the cluster module)."
  }
}

variable "fargate_execution_role_name" {
  description = "Name of the Fargate execution role to attach CloudMap permissions to"
  type        = string
  default     = ""
}



variable "controller_version" {
  description = "Version of the MCS controller to install"
  type        = string
  default     = "v0.3.1"
}

variable "tags" {
  description = "A map of tags to assign to the resources"
  type        = map(string)
  default     = {}
}
