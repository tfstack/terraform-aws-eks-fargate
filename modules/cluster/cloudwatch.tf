##############################
# CloudWatch Log Group: EKS Cluster Logs
##############################

resource "aws_cloudwatch_log_group" "eks_cluster_with_prevent_destroy" {
  count = var.eks_log_prevent_destroy ? 1 : 0

  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.eks_log_retention_days

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name = "${var.cluster_name}-cluster"
  }
}

resource "aws_cloudwatch_log_group" "eks_cluster_without_prevent_destroy" {
  count = var.eks_log_prevent_destroy ? 0 : 1

  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.eks_log_retention_days

  lifecycle {
    prevent_destroy = false
  }

  tags = {
    Name = "${var.cluster_name}-cluster"
  }
}

##############################
# CloudWatch Log Group: EKS General Logs
##############################

resource "aws_cloudwatch_log_group" "eks_logs_with_prevent_destroy" {
  count = var.eks_log_prevent_destroy ? 1 : 0

  name              = "/aws/eks/${var.cluster_name}/logs"
  retention_in_days = var.eks_log_retention_days

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name = "${var.cluster_name}-logs"
  }
}

resource "aws_cloudwatch_log_group" "eks_logs_without_prevent_destroy" {
  count = var.eks_log_prevent_destroy ? 0 : 1

  name              = "/aws/eks/${var.cluster_name}/logs"
  retention_in_days = var.eks_log_retention_days

  lifecycle {
    prevent_destroy = false
  }

  tags = {
    Name = "${var.cluster_name}-logs"
  }
}
