<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.90.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_iam_role.karpenter_node_trust_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.attach_AmazonSSMManagedInstanceCore](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | This is the name of your cluster | `string` | `"dev"` | no |
| <a name="input_karpenter_role_attatchments"></a> [karpenter\_role\_attatchments](#input\_karpenter\_role\_attatchments) | The iam roles attatched to karpenter policy, consult documentation for karpenter | `list(string)` | <pre>[<br/>  "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"<br/>]</pre> | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->