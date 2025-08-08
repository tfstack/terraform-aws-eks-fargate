############################################
# Data Sources
############################################

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

#########################################
# Module: EKS Cluster
#########################################

module "cluster" {
  source = "./modules/cluster"

  cluster_name              = var.cluster_name
  cluster_version           = var.cluster_version
  tags                      = var.tags
  vpc_id                    = var.vpc_id
  cluster_vpc_config        = var.cluster_vpc_config
  cluster_enabled_log_types = var.cluster_enabled_log_types
  enable_cluster_encryption = var.enable_cluster_encryption
  enable_oidc               = var.enable_oidc
  eks_log_prevent_destroy   = var.eks_log_prevent_destroy
  eks_log_retention_days    = var.eks_log_retention_days
}

#########################################
# Module: Namespaces
#########################################

module "namespaces" {
  source = "./modules/namespaces"

  namespaces           = var.namespaces
  enable_observability = var.enable_cloudwatch_observability

  depends_on = [
    module.cluster
  ]
}

#########################################
# Module: Fargate Profiles
#########################################

module "fargate_profiles" {
  source = "./modules/fargate_profiles"

  cluster_name           = var.cluster_name
  pod_execution_role_arn = module.cluster.eks_fargate_pod_execution_role_arn
  private_subnet_ids     = var.cluster_vpc_config.private_subnet_ids

  enable_coredns        = var.enable_coredns_addon
  enable_metrics_server = var.enable_metrics_server_addon
  #   enable_aws_observability = true

  profiles = var.fargate_profiles

  depends_on = [
    module.namespaces
  ]
}

#########################################
# Module: EKS Addons
#########################################

module "addons" {
  source = "./modules/addons"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version
  tags            = var.tags

  enable_addons = {
    vpc_cni        = var.enable_vpc_cni_addon
    coredns        = var.enable_coredns_addon
    kube_proxy     = var.enable_kube_proxy_addon
    metrics_server = var.enable_metrics_server_addon
    pod_identity   = var.enable_pod_identity_agent_addon
  }

  addon_versions = {
    vpc_cni        = var.vpc_cni_addon_version
    coredns        = var.coredns_addon_version
    kube_proxy     = var.kube_proxy_addon_version
    metrics_server = var.metrics_server_addon_version
    pod_identity   = var.pod_identity_agent_addon_version
  }

  depends_on = [
    module.fargate_profiles
  ]
}

#########################################
# Module: CloudWatch Logging
#########################################

module "cloudwatch_logging" {
  source = "./modules/cloudwatch_logging"

  enabled = var.enable_cloudwatch_observability

  cluster_name                    = var.cluster_name
  region                          = data.aws_region.current.region
  account_id                      = data.aws_caller_identity.current.account_id
  fargate_pod_execution_role_name = module.cluster.eks_fargate_pod_execution_role_name
  log_prevent_destroy             = var.eks_log_prevent_destroy
  log_retention_days              = var.eks_log_retention_days

  depends_on = [
    module.fargate_profiles
  ]
}

# #########################################
# # Module: CloudMap Integration
# #########################################

# module "cloudmap_integration" {
#   source = "./modules/cloudmap-integration"

#   enable_cloudmap                            = var.enable_cloudmap
#   cloudmap_namespace_name                    = var.cloudmap_namespace_name
#   cloudmap_namespace_description             = var.cloudmap_namespace_description
#   vpc_id                                     = var.vpc_id
#   cloudmap_services                          = var.cloudmap_services
#   cloudmap_create_ecs_service_discovery_role = var.cloudmap_create_ecs_service_discovery_role
#   tags                                       = var.tags

#   depends_on = [
#     module.cloudwatch_logging
#   ]
# }

# #########################################
# # Module: MCS Controller
# #########################################

# module "mcs_controller" {
#   source = "./modules/mcs-controller"

#   enabled            = var.enable_mcs_controller
#   cluster_name       = var.cluster_name
#   oidc_provider_arn  = module.cluster.oidc_provider_arn
#   controller_version = var.mcs_controller_version
#   tags               = var.tags

#   depends_on = [
#     module.addons
#   ]
# }

#########################################

#########################################
# Module: Workloads
#########################################

module "workload" {
  for_each = { for w in var.workloads : w.name => w }

  source = "./modules/workload"

  cluster_name     = var.cluster_name
  name             = each.value.name
  namespace        = each.value.namespace
  create_namespace = try(each.value.create_namespace, false)
  replicas         = try(each.value.replicas, 1)
  labels           = try(each.value.labels, {})

  logging = {
    enabled = try(each.value.logging.enabled, false)
    fargate_role_arn = (
      try(each.value.logging.use_cluster_fargate_role, false)
      ? module.cluster.eks_fargate_pod_execution_role_arn
      : try(each.value.logging.fargate_role_arn, null)
    )
  }

  irsa = {
    enabled = try(each.value.irsa.enabled, false)
    oidc_provider_arn = (
      try(each.value.irsa.use_cluster_oidc_provider, false)
      ? module.cluster.oidc_provider_arn
      : try(each.value.irsa.oidc_provider_arn, null)
    )
    policy_arns = try(each.value.irsa.policy_arns, [])
  }

  containers      = each.value.containers
  init_containers = try(each.value.init_containers, [])
  volumes         = try(each.value.volumes, [])
  configmaps      = try(each.value.configmaps, [])

  # Service configuration
  create_service      = try(each.value.create_service, false)
  service_type        = try(each.value.service_type, "ClusterIP")
  service_ports       = try(each.value.service_ports, [])
  service_annotations = try(each.value.service_annotations, {})

  depends_on = [
    module.addons,
    module.cloudwatch_logging
  ]
}
