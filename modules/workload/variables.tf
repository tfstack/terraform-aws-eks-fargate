#########################################
# Workload Identity & Namespace
#########################################

variable "name" {
  description = "Workload base name (used for SA, ConfigMap, Deployment)"
  type        = string

  validation {
    condition     = length(var.name) > 0
    error_message = "The workload name must not be empty."
  }
}

variable "namespace" {
  description = "Kubernetes namespace to deploy the workload"
  type        = string

  validation {
    condition     = length(var.namespace) > 0
    error_message = "The namespace must not be empty."
  }
}

variable "create_namespace" {
  description = "Whether to create the namespace"
  type        = bool
  default     = false
}

variable "namespace_metadata" {
  description = "Optional metadata to apply when creating the namespace (labels and annotations)"
  type = object({
    labels      = optional(map(string), {})
    annotations = optional(map(string), {})
  })
  default = {}
}

variable "service_account_name" {
  description = "Override service account name (defaults to workload name)"
  type        = string
  default     = null
}

#########################################
# Workload Runtime Configuration
#########################################

variable "containers" {
  description = "List of container specs"
  type = list(object({
    name      = string
    image     = string
    command   = optional(list(string))
    args      = optional(list(string))
    env       = optional(list(map(string)))
    resources = optional(map(any))
    volume_mounts = optional(list(object({
      name       = string
      mount_path = string
    })))
  }))

  validation {
    condition     = length(var.containers) > 0
    error_message = "At least one container must be defined."
  }
}

variable "init_containers" {
  description = "Optional list of init containers to run before app containers"
  type = list(object({
    name    = string
    image   = string
    command = optional(list(string))
    args    = optional(list(string))
    env     = optional(list(map(string)))
    volume_mounts = optional(list(object({
      name       = string
      mount_path = string
    })))
  }))
  default = []
}

variable "volumes" {
  description = "List of pod-level volumes"
  type = list(object({
    name       = string
    config_map = optional(object({ name = string }))
    secret     = optional(object({ secret_name = string }))
  }))
  default = []
}

variable "configmaps" {
  description = "List of ConfigMaps to create"
  type = list(object({
    name = string
    data = map(string)
  }))
  default = []
}

variable "replicas" {
  description = "Number of pod replicas to run"
  type        = number
  default     = 1

  validation {
    condition     = var.replicas >= 1
    error_message = "You must specify at least one replica."
  }
}

variable "labels" {
  description = "Additional labels to apply to deployment and pod templates"
  type        = map(string)
  default     = {}
}

#########################################
# Logging & Observability
#########################################

variable "logging" {
  description = "Fluent Bit logging configuration"
  type = object({
    enabled          = bool
    fargate_role_arn = optional(string)
  })
  default = {
    enabled = false
  }
}

#########################################
# IAM Role for Service Account (IRSA)
#########################################

variable "irsa" {
  description = "IRSA configuration"
  type = object({
    enabled           = bool
    oidc_provider_arn = optional(string)
    policy_arns       = optional(list(string))
  })
  default = {
    enabled = false
  }

  validation {
    condition = (!var.irsa.enabled) || (
      var.irsa.oidc_provider_arn != null &&
      length(var.irsa.policy_arns) > 0
    )
    error_message = "When IRSA is enabled, both 'oidc_provider_arn' and at least one 'policy_arn' must be provided."
  }
}

#########################################
# Cluster & Metadata
#########################################

variable "cluster_name" {
  description = "EKS cluster name (used in IRSA role naming)"
  type        = string

  validation {
    condition     = length(var.cluster_name) > 0
    error_message = "The cluster name must not be empty."
  }
}

variable "tags" {
  description = "Tags to apply to taggable resources (e.g. IAM roles)"
  type        = map(string)
  default     = {}
}
