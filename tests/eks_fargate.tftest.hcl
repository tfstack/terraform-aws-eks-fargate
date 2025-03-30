run "setup" {
  module {
    source = "./tests/setup"
  }
}

run "eks_fargate_test" {
  variables {
    cluster_name    = "eks-test-${run.setup.suffix}"
    cluster_version = "1.32"
    tags = {
      Environment = "test"
      Terraform   = "true"
    }

    vpc_id = run.setup.vpc_id

    cluster_vpc_config = {
      subnet_ids           = run.setup.private_subnet_ids
      private_subnet_ids   = run.setup.private_subnet_ids
      private_access_cidrs = run.setup.private_subnet_cidrs
      public_access_cidrs  = ["0.0.0.0/0"]
      service_cidr         = "10.100.0.0/16"

      security_group_ids      = []
      endpoint_private_access = false
      endpoint_public_access  = true
    }

    enable_cluster_encryption = false
    enable_oidc               = true
    eks_log_prevent_destroy   = false
    eks_log_retention_days    = 1

    # Configure namespaces
    namespaces = [
      {
        name = "demo"
        labels = {
          "purpose" = "e2e"
        }
      }
    ]

    # Configure Fargate profiles
    fargate_profiles = [
      {
        name       = "demo"
        subnet_ids = run.setup.private_subnet_ids

        selectors = [
          {
            namespace = "demo"
          }
        ]
      }
    ]

    # Enable basic addons
    enable_vpc_cni_addon    = true
    enable_coredns_addon    = true
    enable_kube_proxy_addon = true

    # Configure a basic workload
    workloads = [
      {
        name      = "logger-test"
        namespace = "demo"
        replicas  = 2
        labels    = { purpose = "e2e" }

        logging = {
          enabled                  = false
          use_cluster_fargate_role = false
        }

        irsa = {
          enabled                   = false
          use_cluster_oidc_provider = false
          policy_arns               = []
        }

        containers = [{
          name    = "logger"
          image   = "public.ecr.aws/bitnami/nginx"
          command = ["/bin/sh", "-c"]
          args    = ["while true; do echo hello from nginx $(date); sleep 5; done"]
        }]
      }
    ]
  }

  # Validate EKS cluster creation
  assert {
    condition     = length(module.cluster.cluster_name) > 0
    error_message = "EKS Cluster was not created successfully."
  }

  # Validate Fargate profiles
  assert {
    condition     = length(module.fargate_profiles.fargate_profile_names) > 0
    error_message = "Fargate profiles were not created successfully."
  }

  # Validate workload deployment
  assert {
    condition     = anytrue([for w in values(module.workload) : length(w.configmap_names) >= 0])
    error_message = "Workloads were not created successfully."
  }
}
