##############################
# EKS Cluster Configuration
##############################

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = <<EOF
EKS Kubernetes version

Optional. Use:
- A specific version (e.g. "1.29") to pin the cluster version
- "latest" or null to let EKS use the latest version at creation
EOF
  type        = string
  default     = null
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

##############################
# Networking
##############################

variable "vpc_id" {
  description = "VPC ID where the EKS cluster will be deployed"
  type        = string

  validation {
    condition     = can(regex("^vpc-[a-f0-9]+$", var.vpc_id))
    error_message = "The VPC ID must be in the format 'vpc-xxxxxxxxxxxxxxxxx'."
  }
}

variable "create_security_group" {
  description = "Whether to create an internal security group for EKS"
  type        = bool
  default     = true
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

##############################
# Optional Features
##############################

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

##############################
# CloudWatch Logging
##############################

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

##############################
# Metadata
##############################

variable "tags" {
  description = "A map of tags to use on all resources"
  type        = map(string)
  default     = {}
}
