# Terraform submodule to manage core EKS addons such as vpc-cni, coredns, kube-proxy, metrics-server, and eks-pod-identity-agent

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
| [aws_eks_addon.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_addon) | resource |
| [aws_eks_addon_version.latest](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_addon_version) | data source |
| [aws_eks_cluster_versions.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster_versions) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_addon_versions"></a> [addon\_versions](#input\_addon\_versions) | n/a | `map(string)` | n/a | yes |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | n/a | `string` | n/a | yes |
| <a name="input_cluster_version"></a> [cluster\_version](#input\_cluster\_version) | n/a | `string` | `"latest"` | no |
| <a name="input_enable_addons"></a> [enable\_addons](#input\_enable\_addons) | n/a | <pre>object({<br/>    vpc_cni        = bool<br/>    coredns        = bool<br/>    kube_proxy     = bool<br/>    metrics_server = bool<br/>    pod_identity   = bool<br/>  })</pre> | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to use on all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_eks_addons"></a> [eks\_addons](#output\_eks\_addons) | Map of EKS addon names to their resolved versions |
<!-- END_TF_DOCS -->
