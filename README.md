# terraform-aws-eks-fargate

Terraform module to deploy AWS EKS Fargate profiles for serverless workloads

<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.97.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_addons"></a> [addons](#module\_addons) | ./modules/addons | n/a |
| <a name="module_cloudwatch_logging"></a> [cloudwatch\_logging](#module\_cloudwatch\_logging) | ./modules/cloudwatch_logging | n/a |
| <a name="module_cluster"></a> [cluster](#module\_cluster) | ./modules/cluster | n/a |
| <a name="module_fargate_profiles"></a> [fargate\_profiles](#module\_fargate\_profiles) | ./modules/fargate_profiles | n/a |
| <a name="module_namespaces"></a> [namespaces](#module\_namespaces) | ./modules/namespaces | n/a |
| <a name="module_workload"></a> [workload](#module\_workload) | ./modules/workload | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cluster_enabled_log_types"></a> [cluster\_enabled\_log\_types](#input\_cluster\_enabled\_log\_types) | List of enabled cluster log types | `list(string)` | `[]` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Name of the EKS cluster | `string` | n/a | yes |
| <a name="input_cluster_upgrade_policy"></a> [cluster\_upgrade\_policy](#input\_cluster\_upgrade\_policy) | Upgrade policy for EKS cluster | <pre>object({<br/>    support_type = optional(string, null)<br/>  })</pre> | `{}` | no |
| <a name="input_cluster_version"></a> [cluster\_version](#input\_cluster\_version) | EKS Kubernetes version | `string` | `"latest"` | no |
| <a name="input_cluster_vpc_config"></a> [cluster\_vpc\_config](#input\_cluster\_vpc\_config) | VPC configuration for EKS | <pre>object({<br/>    subnet_ids              = list(string)<br/>    private_subnet_ids      = list(string)<br/>    private_access_cidrs    = list(string)<br/>    public_access_cidrs     = list(string)<br/>    service_cidr            = string<br/>    security_group_ids      = list(string)<br/>    endpoint_private_access = bool<br/>    endpoint_public_access  = bool<br/>  })</pre> | n/a | yes |
| <a name="input_cluster_zonal_shift_config"></a> [cluster\_zonal\_shift\_config](#input\_cluster\_zonal\_shift\_config) | Zonal shift configuration | <pre>object({<br/>    enabled = optional(bool, false)<br/>  })</pre> | `{}` | no |
| <a name="input_coredns_addon_version"></a> [coredns\_addon\_version](#input\_coredns\_addon\_version) | Version of the CoreDNS addon | `string` | `"latest"` | no |
| <a name="input_create_security_group"></a> [create\_security\_group](#input\_create\_security\_group) | Whether to create an internal security group for EKS | `bool` | `true` | no |
| <a name="input_eks_log_prevent_destroy"></a> [eks\_log\_prevent\_destroy](#input\_eks\_log\_prevent\_destroy) | Whether to prevent the destruction of the CloudWatch log group | `bool` | `true` | no |
| <a name="input_eks_log_retention_days"></a> [eks\_log\_retention\_days](#input\_eks\_log\_retention\_days) | The number of days to retain logs for the EKS in CloudWatch | `number` | `30` | no |
| <a name="input_enable_cloudwatch_observability"></a> [enable\_cloudwatch\_observability](#input\_enable\_cloudwatch\_observability) | Whether to enable CloudWatch observability features such as logging and metrics. | `bool` | `false` | no |
| <a name="input_enable_cluster_encryption"></a> [enable\_cluster\_encryption](#input\_enable\_cluster\_encryption) | Enable encryption for Kubernetes secrets using a KMS key | `bool` | `false` | no |
| <a name="input_enable_coredns_addon"></a> [enable\_coredns\_addon](#input\_enable\_coredns\_addon) | Enable the CoreDNS EKS addon | `bool` | `false` | no |
| <a name="input_enable_kube_proxy_addon"></a> [enable\_kube\_proxy\_addon](#input\_enable\_kube\_proxy\_addon) | Enable the kube-proxy EKS addon | `bool` | `false` | no |
| <a name="input_enable_metrics_server_addon"></a> [enable\_metrics\_server\_addon](#input\_enable\_metrics\_server\_addon) | Enable the Metrics Server EKS addon | `bool` | `false` | no |
| <a name="input_enable_oidc"></a> [enable\_oidc](#input\_enable\_oidc) | Enable IAM OIDC provider on the EKS cluster | `bool` | `true` | no |
| <a name="input_enable_pod_identity_agent_addon"></a> [enable\_pod\_identity\_agent\_addon](#input\_enable\_pod\_identity\_agent\_addon) | Enable the EKS Pod Identity Agent addon | `bool` | `false` | no |
| <a name="input_enable_vpc_cni_addon"></a> [enable\_vpc\_cni\_addon](#input\_enable\_vpc\_cni\_addon) | Enable the VPC CNI EKS addon | `bool` | `false` | no |
| <a name="input_fargate_profiles"></a> [fargate\_profiles](#input\_fargate\_profiles) | Explicit list of Fargate profile configurations | <pre>list(object({<br/>    name       = string<br/>    subnet_ids = list(string)<br/>    tags       = optional(map(string), {})<br/>    selectors = list(object({<br/>      namespace = string<br/>      labels    = optional(map(string))<br/>    }))<br/>  }))</pre> | `null` | no |
| <a name="input_kube_proxy_addon_version"></a> [kube\_proxy\_addon\_version](#input\_kube\_proxy\_addon\_version) | Version of the kube-proxy addon | `string` | `"latest"` | no |
| <a name="input_metrics_server_addon_version"></a> [metrics\_server\_addon\_version](#input\_metrics\_server\_addon\_version) | Version of the Metrics Server EKS addon | `string` | `"latest"` | no |
| <a name="input_namespaces"></a> [namespaces](#input\_namespaces) | User-defined list of namespaces | <pre>list(object({<br/>    name   = string<br/>    labels = optional(map(string), {})<br/>  }))</pre> | `null` | no |
| <a name="input_pod_identity_agent_addon_version"></a> [pod\_identity\_agent\_addon\_version](#input\_pod\_identity\_agent\_addon\_version) | Version of the Pod Identity Agent addon | `string` | `"latest"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to use on all resources | `map(string)` | `{}` | no |
| <a name="input_timeouts"></a> [timeouts](#input\_timeouts) | Timeouts for EKS cluster creation, update, and deletion | <pre>object({<br/>    create = optional(string, null)<br/>    update = optional(string, null)<br/>    delete = optional(string, null)<br/>  })</pre> | `{}` | no |
| <a name="input_vpc_cni_addon_version"></a> [vpc\_cni\_addon\_version](#input\_vpc\_cni\_addon\_version) | Version of the VPC CNI addon | `string` | `"latest"` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC ID where the EKS cluster will be deployed | `string` | n/a | yes |
| <a name="input_workloads"></a> [workloads](#input\_workloads) | List of workload definitions for bulk instantiation | <pre>list(object({<br/>    name             = string<br/>    namespace        = string<br/>    create_namespace = optional(bool, false)<br/>    replicas         = optional(number, 1)<br/>    labels           = optional(map(string), {})<br/>    logging = optional(object({<br/>      enabled                  = bool<br/>      use_cluster_fargate_role = optional(bool, false)<br/>    }), { enabled = false })<br/>    irsa = optional(object({<br/>      enabled                   = bool<br/>      use_cluster_oidc_provider = optional(bool, false)<br/>      policy_arns               = optional(list(string))<br/>    }), { enabled = false })<br/>    containers      = list(any)<br/>    init_containers = optional(list(any), [])<br/>    volumes         = optional(list(any), [])<br/>    configmaps      = optional(list(any), [])<br/>  }))</pre> | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | The name of the EKS cluster |
| <a name="output_cluster_version"></a> [cluster\_version](#output\_cluster\_version) | The Kubernetes version used for the EKS cluster |
| <a name="output_eks_addons"></a> [eks\_addons](#output\_eks\_addons) | Versions of enabled EKS addons |
| <a name="output_eks_cluster_auth_token"></a> [eks\_cluster\_auth\_token](#output\_eks\_cluster\_auth\_token) | Authentication token for the EKS cluster (used by kubectl and SDKs) |
| <a name="output_eks_cluster_ca_cert"></a> [eks\_cluster\_ca\_cert](#output\_eks\_cluster\_ca\_cert) | The base64-decoded certificate authority data for the EKS cluster |
| <a name="output_eks_cluster_endpoint"></a> [eks\_cluster\_endpoint](#output\_eks\_cluster\_endpoint) | The endpoint URL of the EKS cluster |
| <a name="output_eks_fargate_pod_execution_role_arn"></a> [eks\_fargate\_pod\_execution\_role\_arn](#output\_eks\_fargate\_pod\_execution\_role\_arn) | ARN of the EKS Fargate Pod Execution IAM Role |
| <a name="output_eks_fargate_pod_execution_role_name"></a> [eks\_fargate\_pod\_execution\_role\_name](#output\_eks\_fargate\_pod\_execution\_role\_name) | Name of the EKS Fargate Pod Execution IAM Role |
| <a name="output_fargate_profile_names"></a> [fargate\_profile\_names](#output\_fargate\_profile\_names) | List of Fargate profile names |
| <a name="output_fargate_profile_selectors"></a> [fargate\_profile\_selectors](#output\_fargate\_profile\_selectors) | Map of Fargate profile name to its pod selectors |
| <a name="output_namespace_annotations"></a> [namespace\_annotations](#output\_namespace\_annotations) | Annotations applied to each namespace |
| <a name="output_namespace_labels"></a> [namespace\_labels](#output\_namespace\_labels) | Labels applied to each namespace |
| <a name="output_namespace_names"></a> [namespace\_names](#output\_namespace\_names) | List of created namespace names |
| <a name="output_oidc_provider_arn"></a> [oidc\_provider\_arn](#output\_oidc\_provider\_arn) | OIDC provider ARN for the EKS cluster, used for IRSA |
| <a name="output_oidc_provider_url"></a> [oidc\_provider\_url](#output\_oidc\_provider\_url) | OIDC provider URL for the EKS cluster, used for IRSA |
| <a name="output_workload_configmap_names"></a> [workload\_configmap\_names](#output\_workload\_configmap\_names) | Map of workload name to list of ConfigMap names |
| <a name="output_workload_deployment_names"></a> [workload\_deployment\_names](#output\_workload\_deployment\_names) | Map of workload name to its Kubernetes Deployment name |
| <a name="output_workload_irsa_role_arns"></a> [workload\_irsa\_role\_arns](#output\_workload\_irsa\_role\_arns) | Map of workload name to its IRSA role ARN (null if not created) |
| <a name="output_workload_service_account_names"></a> [workload\_service\_account\_names](#output\_workload\_service\_account\_names) | Map of workload name to its ServiceAccount name |
<!-- END_TF_DOCS -->
