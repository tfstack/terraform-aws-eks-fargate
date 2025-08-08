variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "cls1"
}

variable "aws_region" {
  description = "AWS region for the cluster"
  type        = string
  default     = "ap-southeast-2"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.10.0.0/16"
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.28"
}

variable "nodegroup_name" {
  description = "Name of the EKS node group"
  type        = string
  default     = "cls1-nodegroup1"
}

variable "cluster_set_id" {
  description = "ClusterSet ID for MCS Controller"
  type        = string
  default     = "clusterset1"
}

variable "cluster_id" {
  description = "Cluster ID for MCS Controller"
  type        = string
  default     = "cls1"
}

variable "namespace" {
  description = "Namespace for MCS Controller"
  type        = string
  default     = "cloud-map-mcs-system"
}

variable "demo_namespace" {
  description = "Namespace for demo applications"
  type        = string
  default     = "demo"
}

variable "node_instance_type" {
  description = "Instance type for EKS nodes"
  type        = string
  default     = "t2.small"
}

variable "node_desired_size" {
  description = "Desired number of nodes in the node group"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of nodes in the node group"
  type        = number
  default     = 10
}

variable "node_min_size" {
  description = "Minimum number of nodes in the node group"
  type        = number
  default     = 1
} 