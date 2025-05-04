# Reusable Terraform submodule to deploy workloads on AWS EKS Fargate with support for IRSA, configmaps, init containers, and optional Fluent Bit logging

<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | n/a |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | n/a |
| <a name="provider_null"></a> [null](#provider\_null) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_iam_role.irsa](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [kubernetes_config_map.this](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/config_map) | resource |
| [kubernetes_deployment.this](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/deployment) | resource |
| [kubernetes_namespace.this](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |
| [kubernetes_service_account.this](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_account) | resource |
| [null_resource.configmap_trigger](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | EKS cluster name (used in IRSA role naming) | `string` | n/a | yes |
| <a name="input_configmaps"></a> [configmaps](#input\_configmaps) | List of ConfigMaps to create | <pre>list(object({<br/>    name = string<br/>    data = map(string)<br/>  }))</pre> | `[]` | no |
| <a name="input_containers"></a> [containers](#input\_containers) | List of container specs | <pre>list(object({<br/>    name      = string<br/>    image     = string<br/>    command   = optional(list(string))<br/>    args      = optional(list(string))<br/>    env       = optional(list(map(string)))<br/>    resources = optional(map(any))<br/>    volume_mounts = optional(list(object({<br/>      name       = string<br/>      mount_path = string<br/>    })))<br/>  }))</pre> | n/a | yes |
| <a name="input_create_namespace"></a> [create\_namespace](#input\_create\_namespace) | Whether to create the namespace | `bool` | `false` | no |
| <a name="input_init_containers"></a> [init\_containers](#input\_init\_containers) | Optional list of init containers to run before app containers | <pre>list(object({<br/>    name    = string<br/>    image   = string<br/>    command = optional(list(string))<br/>    args    = optional(list(string))<br/>    env     = optional(list(map(string)))<br/>    volume_mounts = optional(list(object({<br/>      name       = string<br/>      mount_path = string<br/>    })))<br/>  }))</pre> | `[]` | no |
| <a name="input_irsa"></a> [irsa](#input\_irsa) | IRSA configuration | <pre>object({<br/>    enabled           = bool<br/>    oidc_provider_arn = optional(string)<br/>    policy_arns       = optional(list(string))<br/>  })</pre> | <pre>{<br/>  "enabled": false<br/>}</pre> | no |
| <a name="input_labels"></a> [labels](#input\_labels) | Additional labels to apply to deployment and pod templates | `map(string)` | `{}` | no |
| <a name="input_logging"></a> [logging](#input\_logging) | Fluent Bit logging configuration | <pre>object({<br/>    enabled          = bool<br/>    fargate_role_arn = optional(string)<br/>  })</pre> | <pre>{<br/>  "enabled": false<br/>}</pre> | no |
| <a name="input_name"></a> [name](#input\_name) | Workload base name (used for SA, ConfigMap, Deployment) | `string` | n/a | yes |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Kubernetes namespace to deploy the workload | `string` | n/a | yes |
| <a name="input_namespace_metadata"></a> [namespace\_metadata](#input\_namespace\_metadata) | Optional metadata to apply when creating the namespace (labels and annotations) | <pre>object({<br/>    labels      = optional(map(string), {})<br/>    annotations = optional(map(string), {})<br/>  })</pre> | `{}` | no |
| <a name="input_replicas"></a> [replicas](#input\_replicas) | Number of pod replicas to run | `number` | `1` | no |
| <a name="input_service_account_name"></a> [service\_account\_name](#input\_service\_account\_name) | Override service account name (defaults to workload name) | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to taggable resources (e.g. IAM roles) | `map(string)` | `{}` | no |
| <a name="input_volumes"></a> [volumes](#input\_volumes) | List of pod-level volumes | <pre>list(object({<br/>    name       = string<br/>    config_map = optional(object({ name = string }))<br/>    secret     = optional(object({ secret_name = string }))<br/>  }))</pre> | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_configmap_names"></a> [configmap\_names](#output\_configmap\_names) | List of created ConfigMap names |
| <a name="output_deployment_name"></a> [deployment\_name](#output\_deployment\_name) | Name of the Kubernetes deployment |
| <a name="output_irsa_role_arn"></a> [irsa\_role\_arn](#output\_irsa\_role\_arn) | IRSA role ARN if created |
| <a name="output_service_account_name"></a> [service\_account\_name](#output\_service\_account\_name) | Name of the Kubernetes service account used by the workload |
<!-- END_TF_DOCS -->
