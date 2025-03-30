# Terraform submodule to manage Kubernetes namespaces with optional toggles for CloudWatch and aws-observability support

<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [kubernetes_namespace.this](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_enable_cloudwatch"></a> [enable\_cloudwatch](#input\_enable\_cloudwatch) | Toggle for amazon-cloudwatch namespace | `bool` | `false` | no |
| <a name="input_enable_observability"></a> [enable\_observability](#input\_enable\_observability) | Toggle for observability namespace | `bool` | `false` | no |
| <a name="input_namespaces"></a> [namespaces](#input\_namespaces) | User-defined list of namespaces | <pre>list(object({<br/>    name   = string<br/>    labels = optional(map(string), {})<br/>  }))</pre> | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_namespace_annotations"></a> [namespace\_annotations](#output\_namespace\_annotations) | Map of namespace names to their annotations |
| <a name="output_namespace_labels"></a> [namespace\_labels](#output\_namespace\_labels) | Map of namespace names to their labels |
| <a name="output_namespace_names"></a> [namespace\_names](#output\_namespace\_names) | List of all created Kubernetes namespaces |
<!-- END_TF_DOCS -->
