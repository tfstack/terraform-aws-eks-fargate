#########################################
# EKS Access Entry for Terraform Executor
#########################################

resource "aws_eks_access_entry" "terraform_executor" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.executor_role_name}"
}

resource "aws_eks_access_policy_association" "terraform_executor" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = aws_eks_access_entry.terraform_executor.principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}
