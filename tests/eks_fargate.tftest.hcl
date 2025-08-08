run "validate_module_structure" {
  command = plan

  variables {
    cluster_name    = "test-cluster"
    cluster_version = "1.33"
    tags = {
      Environment = "test"
      Terraform   = "true"
    }

    vpc_id = "vpc-12345678"

    cluster_vpc_config = {
      subnet_ids           = ["subnet-12345678", "subnet-87654321"]
      private_subnet_ids   = ["subnet-12345678", "subnet-87654321"]
      private_access_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
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
          "purpose" = "test"
        }
      }
    ]

    # Configure Fargate profiles
    fargate_profiles = [
      {
        name       = "demo"
        subnet_ids = ["subnet-12345678", "subnet-87654321"]

        selectors = [
          {
            namespace = "demo"
          }
        ]
      },
      {
        name       = "mcs-controller"
        subnet_ids = ["subnet-12345678", "subnet-87654321"]

        selectors = [
          {
            namespace = "cloud-map-mcs-system"
          }
        ]
      }
    ]

    # Enable basic addons
    enable_vpc_cni_addon    = true
    enable_coredns_addon    = true
    enable_kube_proxy_addon = true

    # CloudMap Service Discovery Configuration
    enable_cloudmap                            = true
    cloudmap_namespace_name                    = "test-namespace"
    cloudmap_namespace_description             = "Test service discovery namespace"
    cloudmap_services                          = {}
    cloudmap_create_ecs_service_discovery_role = false

    # MCS Controller Configuration
    enable_mcs_controller  = true
    mcs_controller_version = "v0.3.1"

    # Configure a basic workload
    workloads = [
      {
        name      = "test-workload"
        namespace = "demo"
        replicas  = 1
        labels    = { purpose = "test" }

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
          name    = "test"
          image   = "public.ecr.aws/bitnami/nginx"
          command = ["/bin/sh", "-c"]
          args    = ["echo 'test'"]
        }]
      }
    ]
  }

  # Simple validation that the configuration is valid
  assert {
    condition     = var.cluster_name == "test-cluster"
    error_message = "Cluster name validation failed."
  }

  assert {
    condition     = var.cluster_version == "1.33"
    error_message = "Cluster version validation failed."
  }

  assert {
    condition     = length(var.workloads) > 0
    error_message = "No workloads configured."
  }
}
