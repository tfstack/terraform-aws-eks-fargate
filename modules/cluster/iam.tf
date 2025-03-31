##############################
# IAM Role for EKS Fargate Cluster
##############################

resource "aws_iam_role" "eks_fargate_cluster" {
  name = "${var.cluster_name}-eks-fargate-cluster"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
      Action = [
        "sts:AssumeRole",
        "sts:TagSession"
      ]
    }]
  })

  tags = merge(
    { "Name" = "${var.cluster_name}-eks-fargate-cluster" },
    var.tags
  )
}

resource "aws_iam_role_policy_attachment" "eks_fargate_cluster" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
    "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  ])

  role       = aws_iam_role.eks_fargate_cluster.name
  policy_arn = each.value
}

##############################
# IAM Role for Fargate Pods
##############################

resource "aws_iam_role" "eks_fargate_pod" {
  name = "${var.cluster_name}-eks-fargate-pod"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "eks-fargate-pods.amazonaws.com"
        },
        Action = "sts:AssumeRole",
        Condition = {
          ArnLike = {
            "aws:SourceArn" = "arn:aws:eks:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:fargateprofile/${var.cluster_name}/*"
          }
        }
      }
    ]
  })
}


resource "aws_iam_role_policy_attachment" "eks_fargate_pod" {
  role       = aws_iam_role.eks_fargate_pod.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
}
