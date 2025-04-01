##############################
# EKS Cluster Configuration
##############################

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

##############################
# Variables: EKS Add-ons
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
