# Reusable Terraform submodule to provision an Amazon EKS cluster with Fargate support, IAM roles, logging, encryption, and optional OIDC integration

<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | n/a |
| <a name="provider_tls"></a> [tls](#provider\_tls) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.eks_cluster_with_prevent_destroy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.eks_cluster_without_prevent_destroy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.eks_logs_with_prevent_destroy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.eks_logs_without_prevent_destroy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_eks_access_entry.terraform_executor](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_access_entry) | resource |
| [aws_eks_access_policy_association.terraform_executor](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_access_policy_association) | resource |
| [aws_eks_cluster.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_cluster) | resource |
| [aws_iam_openid_connect_provider.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_openid_connect_provider) | resource |
| [aws_iam_role.eks_fargate_cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.eks_fargate_pod](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.eks_fargate_cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.eks_fargate_pod](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_kms_alias.eks](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.eks](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_security_group.cluster_control_plane](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.cluster_nodes](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_eks_cluster_auth.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster_auth) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [tls_certificate.eks_oidc](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/data-sources/certificate) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cluster_enabled_log_types"></a> [cluster\_enabled\_log\_types](#input\_cluster\_enabled\_log\_types) | List of enabled cluster log types | `list(string)` | `[]` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Name of the EKS cluster | `string` | n/a | yes |
| <a name="input_cluster_upgrade_policy"></a> [cluster\_upgrade\_policy](#input\_cluster\_upgrade\_policy) | Upgrade policy for EKS cluster | <pre>object({<br/>    support_type = optional(string, null)<br/>  })</pre> | `{}` | no |
| <a name="input_cluster_version"></a> [cluster\_version](#input\_cluster\_version) | EKS Kubernetes version<br/><br/>Optional. Use:<br/>- A specific version (e.g. "1.29") to pin the cluster version<br/>- "latest" or null to let EKS use the latest version at creation | `string` | `null` | no |
| <a name="input_cluster_vpc_config"></a> [cluster\_vpc\_config](#input\_cluster\_vpc\_config) | VPC configuration for EKS | <pre>object({<br/>    subnet_ids              = list(string)<br/>    private_subnet_ids      = list(string)<br/>    private_access_cidrs    = list(string)<br/>    public_access_cidrs     = list(string)<br/>    service_cidr            = string<br/>    security_group_ids      = list(string)<br/>    endpoint_private_access = bool<br/>    endpoint_public_access  = bool<br/>  })</pre> | n/a | yes |
| <a name="input_cluster_zonal_shift_config"></a> [cluster\_zonal\_shift\_config](#input\_cluster\_zonal\_shift\_config) | Zonal shift configuration | <pre>object({<br/>    enabled = optional(bool, false)<br/>  })</pre> | `{}` | no |
| <a name="input_create_security_group"></a> [create\_security\_group](#input\_create\_security\_group) | Whether to create an internal security group for EKS | `bool` | `true` | no |
| <a name="input_eks_log_prevent_destroy"></a> [eks\_log\_prevent\_destroy](#input\_eks\_log\_prevent\_destroy) | Whether to prevent the destruction of the CloudWatch log group | `bool` | `true` | no |
| <a name="input_eks_log_retention_days"></a> [eks\_log\_retention\_days](#input\_eks\_log\_retention\_days) | The number of days to retain logs for the EKS in CloudWatch | `number` | `30` | no |
| <a name="input_enable_cluster_encryption"></a> [enable\_cluster\_encryption](#input\_enable\_cluster\_encryption) | Enable encryption for Kubernetes secrets using a KMS key | `bool` | `false` | no |
| <a name="input_enable_oidc"></a> [enable\_oidc](#input\_enable\_oidc) | Enable IAM OIDC provider on the EKS cluster | `bool` | `true` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to use on all resources | `map(string)` | `{}` | no |
| <a name="input_timeouts"></a> [timeouts](#input\_timeouts) | Timeouts for EKS cluster creation, update, and deletion | <pre>object({<br/>    create = optional(string, null)<br/>    update = optional(string, null)<br/>    delete = optional(string, null)<br/>  })</pre> | `{}` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC ID where the EKS cluster will be deployed | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | The name of the EKS cluster |
| <a name="output_cluster_version"></a> [cluster\_version](#output\_cluster\_version) | The Kubernetes version used for the EKS cluster |
| <a name="output_eks_cluster_auth_token"></a> [eks\_cluster\_auth\_token](#output\_eks\_cluster\_auth\_token) | Authentication token for the EKS cluster (used by kubectl and SDKs) |
| <a name="output_eks_cluster_ca_cert"></a> [eks\_cluster\_ca\_cert](#output\_eks\_cluster\_ca\_cert) | The base64-decoded certificate authority data for the EKS cluster |
| <a name="output_eks_cluster_endpoint"></a> [eks\_cluster\_endpoint](#output\_eks\_cluster\_endpoint) | The endpoint URL of the EKS cluster |
| <a name="output_eks_fargate_pod_execution_role_arn"></a> [eks\_fargate\_pod\_execution\_role\_arn](#output\_eks\_fargate\_pod\_execution\_role\_arn) | ARN of the EKS Fargate Pod Execution IAM Role |
| <a name="output_eks_fargate_pod_execution_role_name"></a> [eks\_fargate\_pod\_execution\_role\_name](#output\_eks\_fargate\_pod\_execution\_role\_name) | Name of the EKS Fargate Pod Execution IAM Role |
| <a name="output_oidc_provider_arn"></a> [oidc\_provider\_arn](#output\_oidc\_provider\_arn) | OIDC provider ARN for the EKS cluster, used for IRSA |
| <a name="output_oidc_provider_url"></a> [oidc\_provider\_url](#output\_oidc\_provider\_url) | OIDC provider URL for the EKS cluster, used for IRSA |
<!-- END_TF_DOCS -->
