terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0.0"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    tls = {
      source = "hashicorp/tls"
    }
    time = {
      source = "hashicorp/time"
    }
  }
}

provider "kubernetes" {
  host                   = module.cluster.eks_cluster_endpoint
  cluster_ca_certificate = module.cluster.eks_cluster_ca_cert
  token                  = module.cluster.eks_cluster_auth_token
}

provider "helm" {
  kubernetes = {
    host                   = module.cluster.eks_cluster_endpoint
    cluster_ca_certificate = module.cluster.eks_cluster_ca_cert
    token                  = module.cluster.eks_cluster_auth_token
  }
}
