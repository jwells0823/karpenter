data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_eks_cluster" "current" {
  name = var.cluster_name
}

data "aws_eks_node_groups" "nodegroup" {
  cluster_name = var.cluster_name
}

data "aws_eks_node_group" "nodegroup_information" {
  for_each        = toset(data.aws_eks_node_groups.nodegroup.names)
  cluster_name    = var.cluster_name
  node_group_name = each.value
}

data "aws_autoscaling_group" "nodegroup_asg" {
  for_each = { for k, v in data.aws_eks_node_group.nodegroup_information : k => v.resources[0].autoscaling_groups[0].name }

  name = each.value
}

data "aws_eks_node_group" "nodegroups" {
  for_each = toset(data.aws_eks_node_groups.nodegroup.names)
  cluster_name = var.cluster_name
  node_group_name = each.value
}

data "http" "karpenter_nodeclaims" {
  url = "https://raw.githubusercontent.com/aws/karpenter-provider-aws/v${var.karpenter_version}/pkg/apis/crds/karpenter.sh_nodeclaims.yaml"
}

data "http" "karpenter_nodepools" {
  url = "https://raw.githubusercontent.com/aws/karpenter-provider-aws/v${var.karpenter_version}/pkg/apis/crds/karpenter.sh_nodepools.yaml"
}

data "http" "karpenter_ec2nodeclasses" {
  url = "https://raw.githubusercontent.com/aws/karpenter-provider-aws/v${var.karpenter_version}/pkg/apis/crds/karpenter.k8s.aws_ec2nodeclasses.yaml"
}

# Remove "https://" from the OIDC endpoint
locals {
  oidc_provider = replace(data.aws_eks_cluster.current.identity[0].oidc[0].issuer, "https://", "")
}

resource "aws_iam_role" "karpenter_node_trust_role" {
  name = "KarpenterNodeRole-${var.cluster_name}"

  assume_role_policy = jsonencode({
    "Version" : "2012-10-17"
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "ec2.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role" "karpenter_fargate_execution_role" {
  name = "KarpenterFargateExecutionRole-${var.cluster_name}"

  assume_role_policy = jsonencode({
    "Version" : "2012-10-17"
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "eks-fargate-pods.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "karpenter_fargate_execution_role_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
  role       = aws_iam_role.karpenter_fargate_execution_role.name
}

resource "aws_iam_role_policy_attachment" "attach_AmazonSSMManagedInstanceCore" {
  for_each   = toset(var.karpenter_role_attatchments)
  role       = aws_iam_role.karpenter_node_trust_role.name
  policy_arn = each.value
}

resource "aws_iam_role" "karpenter_conroller_role" {
  name = "KarpenterControllerRole-${var.cluster_name}"

  assume_role_policy = templatefile("${path.module}/files/templates/roles/karpenter_conroller_role.tpl", {
    account_id               = data.aws_caller_identity.current.account_id
    oidc_provider            = local.oidc_provider
    karpenter_namespace_name = var.karpenter_namespace_name
  })
}

resource "aws_iam_policy" "controller_policy" {
  name        = "KarpenterControllerPolicy-${var.cluster_name}"
  description = "controller policy for karpenter"

  policy = templatefile("${path.module}/files/templates/policies/karpenter_controller_policy.tpl", {
    account_id   = data.aws_caller_identity.current.account_id
    aws_region   = data.aws_region.current.name
    cluster_name = var.cluster_name
  })
}

resource "aws_iam_role_policy_attachment" "attach_policy-conroller" {
  role       = aws_iam_role.karpenter_conroller_role.name
  policy_arn = aws_iam_policy.controller_policy.arn
}

# Tag the subnets for each node group
resource "aws_ec2_tag" "karpenter_discovery" {
  for_each = { for name, nodegroup in data.aws_eks_node_group.nodegroups : name => tolist(nodegroup.subnet_ids)[0] if length(tolist(nodegroup.subnet_ids)) > 0 }
  resource_id = each.value
  key         = "karpenter.sh/discovery"
  value       = var.cluster_name
}

resource "aws_ec2_tag" "karpenter_security_groups" {
  resource_id = data.aws_eks_cluster.current.vpc_config[0].cluster_security_group_id
  key = "karpenter.sh/discovery"
  value = var.cluster_name
}


resource "aws_eks_access_entry" "kaprenter_cluster_access2" {
  cluster_name  = var.cluster_name
  principal_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/KarpenterNodeRole-dev"
  type          = "EC2_LINUX" # or "EC2_WINDOWS" - Linux covers Bottlerocket as well
  
  tags = { 
    env = "dev" 
  }
}

resource "helm_release" "karpenter_base" {
  name       = "karpenter"
  repository = "oci://public.ecr.aws/karpenter"
  version    = var.karpenter_version
  namespace  = var.karpenter_namespace_name
  chart = "karpenter"

  create_namespace = var.create_karpenter_namespace

  values = [templatefile("${path.module}/files/templates/values.yaml", {
    cluster_name = var.cluster_name
    aws_partition = var.aws_partition
#    nodegroup = var.karpenter_nodegroup
    aws_account_id = data.aws_caller_identity.current.account_id
    karpenter_node_group = var.karpenter_node_group
  })]
}

resource "kubectl_manifest" "karpenter_crds" {
  for_each = {
    nodeclaims      = data.http.karpenter_nodeclaims.response_body
    nodepools       = data.http.karpenter_nodepools.response_body
    ec2nodeclasses  = data.http.karpenter_ec2nodeclasses.response_body
  }

  yaml_body = each.value
}

resource "local_file" "karpenter_nodepool" {
  filename = "${path.module}/files/templates/karpenter-nodepool.yaml"
  content  = templatefile("${path.module}/files/templates/karpenter-nodepool.tpl", {
    cluster_name  = var.cluster_name
    alias_version = var.alias_version
  })
}

resource "null_resource" "apply_karpenter_nodepool" {
  depends_on = [local_file.karpenter_nodepool]

  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = "kubectl apply -f ${local_file.karpenter_nodepool.filename}"
  }
}

resource "aws_eks_fargate_profile" "create_karpenter_fargate_profile" {
  cluster_name           = var.cluster_name
  fargate_profile_name   = var.karpenter_namespace_name
  pod_execution_role_arn = aws_iam_role.karpenter_fargate_execution_role.arn
  subnet_ids             = var.karpenter_subnet_ids

  selector {
    namespace = var.karpenter_namespace_name
  }
}

output "karpenter_nodepool_yaml" {
  value = local_file.karpenter_nodepool.content
}
