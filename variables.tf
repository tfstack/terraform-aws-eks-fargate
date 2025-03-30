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

variable "enable_oidc" {
  description = "Enable IAM OIDC provider on the EKS cluster"
  type        = bool
  default     = true
}

#########################################
# VPC and Networking Configuration
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
# IAM and Security Configuration
#########################################

variable "enable_cluster_encryption" {
  description = "Enable encryption for Kubernetes secrets using a KMS key"
  type        = bool
  default     = false
}

#########################################
# Logging and Observability Configuration
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

variable "enable_cloudwatch_observability" {
  description = "Whether to enable CloudWatch observability features such as logging and metrics."
  type        = bool
  default     = false

  validation {
    condition     = var.enable_cloudwatch_observability == false || var.enable_oidc == true
    error_message = "enable_oidc must be true when enable_cloudwatch_observability is true."
  }
}

#########################################
# Fargate Profile Configuration
#########################################

variable "fargate_profiles" {
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

#########################################
# EKS Add-ons Configuration
#########################################

# CoreDNS Addon
variable "enable_coredns_addon" {
  description = "Enable the CoreDNS EKS addon"
  type        = bool
  default     = false
}

variable "coredns_addon_version" {
  description = "Version of the CoreDNS addon"
  type        = string
  default     = "latest"
}

# kube-proxy Addon
variable "enable_kube_proxy_addon" {
  description = "Enable the kube-proxy EKS addon"
  type        = bool
  default     = false
}

variable "kube_proxy_addon_version" {
  description = "Version of the kube-proxy addon"
  type        = string
  default     = "latest"
}

# VPC CNI Addon
variable "enable_vpc_cni_addon" {
  description = "Enable the VPC CNI EKS addon"
  type        = bool
  default     = false
}

variable "vpc_cni_addon_version" {
  description = "Version of the VPC CNI addon"
  type        = string
  default     = "latest"
}

# Metrics Server Addon
variable "enable_metrics_server_addon" {
  description = "Enable the Metrics Server EKS addon"
  type        = bool
  default     = false
}

variable "metrics_server_addon_version" {
  description = "Version of the Metrics Server EKS addon"
  type        = string
  default     = "latest"
}

# Pod Identity Agent Addon
variable "enable_pod_identity_agent_addon" {
  description = "Enable the EKS Pod Identity Agent addon"
  type        = bool
  default     = false

  validation {
    condition     = var.enable_pod_identity_agent_addon == false || var.enable_oidc == true
    error_message = "enable_oidc must be true when enable_pod_identity_agent_addon is true."
  }
}

variable "pod_identity_agent_addon_version" {
  description = "Version of the Pod Identity Agent addon"
  type        = string
  default     = "latest"
}

#########################################
# Namespaces Configuration
#########################################

variable "namespaces" {
  description = "User-defined list of namespaces"
  type = list(object({
    name   = string
    labels = optional(map(string), {})
  }))
  default = null
}

#########################################
# Workload Configuration
#########################################

variable "workloads" {
  description = "List of workload definitions for bulk instantiation"
  type = list(object({
    name             = string
    namespace        = string
    create_namespace = optional(bool, false)
    replicas         = optional(number, 1)
    labels           = optional(map(string), {})
    logging = optional(object({
      enabled                  = bool
      use_cluster_fargate_role = optional(bool, false)
    }), { enabled = false })
    irsa = optional(object({
      enabled                   = bool
      use_cluster_oidc_provider = optional(bool, false)
      policy_arns               = optional(list(string))
    }), { enabled = false })
    containers      = list(any)
    init_containers = optional(list(any), [])
    volumes         = optional(list(any), [])
    configmaps      = optional(list(any), [])
  }))
  default = []

  validation {
    condition = alltrue([
      for w in var.workloads : (
        !try(w.irsa.enabled, false) || (
          try(w.irsa.oidc_provider_arn, null) != null &&
          length(try(w.irsa.policy_arns, [])) > 0
        )
      )
    ])
    error_message = "Each workload with IRSA enabled must include both 'oidc_provider_arn' and at least one 'policy_arn'."
  }
}

#########################################
# Common Metadata and Tagging
#########################################
variable "tags" {
  description = "A map of tags to use on all resources"
  type        = map(string)
  default     = {}
}
