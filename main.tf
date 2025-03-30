# eks-fargate/main.tf

#########################################
# Locals
#########################################

# locals {
#   eks_addons_map = { for addon in var.eks_addons : addon.name => addon }

#   enable_metrics_server = anytrue([
#     for app in var.apps : try(app.autoscaling.enabled, false)
#   ])
# }

#########################################
# Module: EKS Cluster
#########################################

module "cluster" {
  source = "./modules/cluster"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version
  tags            = var.tags
  # eks_auto_node_role_arn        = module.cluster.eks_auto_node_role_arn
  vpc_id                        = var.vpc_id
  cluster_vpc_config            = var.cluster_vpc_config
  cluster_enabled_log_types     = var.cluster_enabled_log_types
  enable_cluster_encryption     = var.enable_cluster_encryption
  enable_elastic_load_balancing = var.enable_elastic_load_balancing
  # enable_irsa                   = var.enable_irsa
  eks_log_prevent_destroy = var.eks_log_prevent_destroy
  eks_log_retention_days  = var.eks_log_retention_days
}



# eks-fargate/
# ├── examples/
# │   └── complete/
# │       └── main.tf                  # Entry point to call the root module
# ├── modules/
# │   └── profile/
# │       ├── main.tf                  # Placeholder with simple output
# │       ├── iam.tf                   # Placeholder for IAM setup
# │       ├── variables.tf             # Module input variables
# │       └── outputs.tf               # Module output values
# ├── main.tf                          # Root module logic (includes data sources and outputs)
# ├── variables.tf                     # Input variables (currently empty)
# ├── outputs.tf                       # Output values (mirrors main.tf for now)
# ├── locals.tf                        # (Optional) for computed values                 # Currently unused, consider moving contents to main.tf
# ├── README.md                        # Documentation
