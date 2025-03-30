#########################################
# AWS Account & Region Data
#########################################

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

#########################################
# Local Values
#########################################

locals {
  # Extracts IAM role name from caller ARN
  executor_role_name = split("/", data.aws_caller_identity.current.arn)[1]

  # Determines EKS cluster version, allows "latest" or null
  resolved_cluster_version = (
    var.cluster_version == null || var.cluster_version == "latest"
    ? null
    : var.cluster_version
  )
}

#########################################
# IAM Role for Terraform Executor
#########################################

data "aws_iam_role" "terraform_executor" {
  name = local.executor_role_name
}
