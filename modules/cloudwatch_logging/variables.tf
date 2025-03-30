#########################################
# General Settings
#########################################

variable "enabled" {
  type    = bool
  default = true
}

#########################################
# EKS Cluster Configuration
#########################################

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "account_id" {
  description = "AWS account ID"
  type        = string
}

#########################################
# IAM and Fargate Role Configuration
#########################################

variable "fargate_pod_execution_role_name" {
  description = "Name of the Fargate pod execution role"
  type        = string
}

#########################################
# CloudWatch Logging Settings
#########################################

variable "log_retention_days" {
  description = "Number of days to retain logs in CloudWatch"
  type        = number
  default     = 30
}

variable "log_prevent_destroy" {
  description = "Whether to prevent the destruction of the CloudWatch log group"
  type        = bool
  default     = true
}

#########################################
# Tags
#########################################

variable "tags" {
  type    = map(string)
  default = {}
}
