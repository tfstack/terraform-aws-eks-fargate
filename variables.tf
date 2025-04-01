#########################################
# EKS Cluster Core Configuration
#########################################

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "EKS Kubernetes version"
  type        = string
  default     = "latest"

  validation {
    condition     = trim(var.cluster_version, " ") != ""
    error_message = "cluster_version must not be an empty string. Use 'latest' or a valid version like '1.29'."
  }
}

variable "cluster_enabled_log_types" {
  description = "List of enabled cluster log types"
  type        = list(string)
  default     = []
}

variable "cluster_upgrade_policy" {
  description = "Upgrade policy for EKS cluster"
  type = object({
    support_type = optional(string, null)
  })
  default = {}
}

variable "cluster_zonal_shift_config" {
  description = "Zonal shift configuration"
  type = object({
    enabled = optional(bool, false)
  })
  default = {}
}

variable "timeouts" {
  description = "Timeouts for EKS cluster creation, update, and deletion"
  type = object({
    create = optional(string, null)
    update = optional(string, null)
    delete = optional(string, null)
  })
  default = {}
}

#########################################
# VPC and Networking
#########################################

variable "vpc_id" {
  description = "VPC ID where the EKS cluster will be deployed"
  type        = string

  validation {
    condition     = can(regex("^vpc-[a-f0-9]+$", var.vpc_id))
    error_message = "The VPC ID must be in the format 'vpc-xxxxxxxxxxxxxxxxx'."
  }
}

variable "cluster_vpc_config" {
  description = "VPC configuration for EKS"
  type = object({
    subnet_ids              = list(string)
    private_subnet_ids      = list(string)
    private_access_cidrs    = list(string)
    public_access_cidrs     = list(string)
    service_cidr            = string
    security_group_ids      = list(string)
    endpoint_private_access = bool
    endpoint_public_access  = bool
  })
}

variable "create_security_group" {
  description = "Whether to create an internal security group for EKS"
  type        = bool
  default     = true
}

#########################################
# Optional Features & IAM
#########################################

variable "enable_cluster_encryption" {
  description = "Enable encryption for Kubernetes secrets using a KMS key"
  type        = bool
  default     = false
}

variable "enable_elastic_load_balancing" {
  description = "Enable or disable Elastic Load Balancing for EKS Auto Mode"
  type        = bool
  default     = true
}

#########################################
# Logging and Observability
#########################################

variable "eks_log_prevent_destroy" {
  description = "Whether to prevent the destruction of the CloudWatch log group"
  type        = bool
  default     = true
}

variable "eks_log_retention_days" {
  description = "The number of days to retain logs for the EKS in CloudWatch"
  type        = number
  default     = 30
}

#########################################
# Common Metadata
#########################################

variable "tags" {
  description = "A map of tags to use on all resources"
  type        = map(string)
  default     = {}
}

##############################
# Variables: EKS Add-ons & Fargate
##############################

variable "eks_addons" {
  description = "List of EKS add-ons to install with optional configurations"
  type = list(object({
    name                        = string
    addon_version               = optional(string, null)
    configuration_values        = optional(string, null)
    resolve_conflicts_on_create = optional(string, "NONE")
    resolve_conflicts_on_update = optional(string, "NONE")
    tags                        = optional(map(string), {})
    preserve                    = optional(bool, false)
    fargate_required            = optional(bool, false)
    namespace                   = optional(string, "kube-system")
    label_override              = optional(string, null)
  }))
  default = []

  validation {
    condition = alltrue([
      for addon in var.eks_addons : length(setsubtract(keys(addon), [
        "name", "addon_version", "configuration_values", "resolve_conflicts_on_create",
        "resolve_conflicts_on_update", "tags", "preserve", "fargate_required",
        "namespace", "label_override"
      ])) == 0
    ])
    error_message = "Each EKS add-on object must contain only the allowed attributes."
  }

  validation {
    condition     = alltrue([for addon in var.eks_addons : addon.resolve_conflicts_on_create == "NONE" || addon.resolve_conflicts_on_create == "OVERWRITE"])
    error_message = "Valid values for 'resolve_conflicts_on_create' are 'NONE' and 'OVERWRITE'."
  }

  validation {
    condition     = alltrue([for addon in var.eks_addons : addon.resolve_conflicts_on_update == "NONE" || addon.resolve_conflicts_on_update == "OVERWRITE" || addon.resolve_conflicts_on_update == "PRESERVE"])
    error_message = "Valid values for 'resolve_conflicts_on_update' are 'NONE', 'OVERWRITE', and 'PRESERVE'."
  }
}

variable "fargate_profiles" {
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
  default = []
}

variable "enable_default_fargate_profile" {
  description = "Enable the default and kube-system Fargate profile"
  type        = bool
  default     = true
}

variable "enable_eks_addons" {
  description = "Enable EKS addons module"
  type        = bool
  default     = true
}
