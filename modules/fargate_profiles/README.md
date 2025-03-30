# Reusable Terraform submodule to create and manage AWS EKS Fargate profiles with support for default, CoreDNS, metrics server, observability, and custom profiles

<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_eks_fargate_profile.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_fargate_profile) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | n/a | `string` | n/a | yes |
| <a name="input_enable_aws_observability"></a> [enable\_aws\_observability](#input\_enable\_aws\_observability) | n/a | `bool` | `false` | no |
| <a name="input_enable_coredns"></a> [enable\_coredns](#input\_enable\_coredns) | n/a | `bool` | `false` | no |
| <a name="input_enable_default"></a> [enable\_default](#input\_enable\_default) | n/a | `bool` | `true` | no |
| <a name="input_enable_metrics_server"></a> [enable\_metrics\_server](#input\_enable\_metrics\_server) | n/a | `bool` | `false` | no |
| <a name="input_pod_execution_role_arn"></a> [pod\_execution\_role\_arn](#input\_pod\_execution\_role\_arn) | n/a | `string` | n/a | yes |
| <a name="input_private_subnet_ids"></a> [private\_subnet\_ids](#input\_private\_subnet\_ids) | n/a | `list(string)` | n/a | yes |
| <a name="input_profiles"></a> [profiles](#input\_profiles) | Explicit list of Fargate profile configurations | <pre>list(object({<br/>    name       = string<br/>    subnet_ids = list(string)<br/>    tags       = optional(map(string), {})<br/>    selectors = list(object({<br/>      namespace = string<br/>      labels    = optional(map(string))<br/>    }))<br/>  }))</pre> | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_fargate_profile_names"></a> [fargate\_profile\_names](#output\_fargate\_profile\_names) | Names of the created Fargate profiles |
| <a name="output_fargate_profile_selectors"></a> [fargate\_profile\_selectors](#output\_fargate\_profile\_selectors) | Map of Fargate profile name to its pod selectors |
<!-- END_TF_DOCS -->
