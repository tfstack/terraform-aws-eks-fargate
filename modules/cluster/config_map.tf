
##############################
# aws-auth ConfigMap
##############################

resource "kubernetes_config_map" "aws_auth" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    mapRoles = yamlencode([
      {
        rolearn  = aws_iam_role.eks_fargate_pod.arn
        username = "system:node:${var.cluster_name}-eks-fargate-pod"
        groups = [
          "system:nodes",
          "system:node-proxier"
        ]
      }
    ])
  }
}
