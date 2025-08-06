terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0.0"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    helm = {
      source = "hashicorp/helm"
    }
    tls = {
      source = "hashicorp/tls"
    }
  }
}

provider "kubernetes" {
  host                   = try(module.eks_fargate.module.cluster.eks_cluster_endpoint, "")
  cluster_ca_certificate = try(base64decode(module.eks_fargate.module.cluster.eks_cluster_ca_cert), "")
  token                  = try(module.eks_fargate.module.cluster.eks_cluster_auth_token, "")
}

provider "helm" {
  kubernetes {
    host                   = try(module.eks_fargate.module.cluster.eks_cluster_endpoint, "")
    cluster_ca_certificate = try(base64decode(module.eks_fargate.module.cluster.eks_cluster_ca_cert), "")
    token                  = try(module.eks_fargate.module.cluster.eks_cluster_auth_token, "")
  }
} 