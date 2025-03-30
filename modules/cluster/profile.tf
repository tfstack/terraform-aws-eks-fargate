#########################################
# Fargate Profile for Default Namespace
#########################################

resource "aws_eks_fargate_profile" "default" {
  cluster_name           = aws_eks_cluster.this.name
  fargate_profile_name   = "default"
  pod_execution_role_arn = aws_iam_role.eks_fargate_pod.arn
  subnet_ids             = var.cluster_vpc_config.private_subnet_ids

  selector {
    namespace = "default"
  }
}
