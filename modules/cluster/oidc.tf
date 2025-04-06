#########################################
# TLS Certificate for EKS OIDC (IRSA)
#########################################

data "tls_certificate" "eks_oidc" {
  count = var.enable_oidc ? 1 : 0

  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

#########################################
# IAM OpenID Connect Provider for EKS (IRSA)
#########################################

resource "aws_iam_openid_connect_provider" "this" {
  count = var.enable_oidc ? 1 : 0

  url            = aws_eks_cluster.this.identity[0].oidc[0].issuer
  client_id_list = ["sts.amazonaws.com"]

  thumbprint_list = [
    data.tls_certificate.eks_oidc[0].certificates[0].sha1_fingerprint
  ]
}
