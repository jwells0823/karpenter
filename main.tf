
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

data "helm_template" "karpenter_template" {
  name       = "karpenter"
  namespace  = var.karpenter_namespace_name
  repository = var.karpenter_repository

  chart   = "karpenter"
  version = var.karpenter_version

  set {
    name  = "settings.clusterName"
    value = var.cluster_name
  }
  set {
    name  = "settings.interruptionQueue"
    value = var.cluster_name
  }
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/KarpenterControllerRole-${var.cluster_name}"
  }
  set {
    name  = "controller.resources.requests.cpu"
    value = "1"
  }
  set {
    name  = "controller.resources.requests.memory"
    value = "1Gi"
  }
  set {
    name  = "controller.resources.limits.cpu"
    value = "1"
  }
  set {
    name  = "controller.resources.limits.memory"
    value = "1Gi"
  }
}


# debugging for outputs. May be useful if you have issues.
#output "nodegroup_security_groups" {
#  value = {
#    for nodegroup_name, lt in data.aws_launch_template.nodegroup_lt :
#    nodegroup_name => lt.security_group_ids
#  }
#}

#output "nodegroup_asg_info" {
#  value = {
#    for nodegroup_name, asg in data.aws_autoscaling_group.nodegroup_asg :
#    nodegroup_name => {
#      asg_name             = asg.name
#      min_size             = asg.min_size
#      max_size             = asg.max_size
#      desired_capacity     = asg.desired_capacity
#      launch_template_name = try(asg.mixed_instances_policy[0].launch_template[0].launch_template_specification[0].launch_template_name, "NO_LAUNCH_TEMPLATE")
#      launch_template_id   = try(asg.mixed_instances_policy[0].launch_template[0].launch_template_specification[0].launch_template_id, "NO_LAUNCH_TEMPLATE")
#      launch_template_version = try(asg.mixed_instances_policy[0].launch_template[0].launch_template_specification[0].version, "UNKNOWN_VERSION")
#      security_groups      = try(asg.vpc_zone_identifier, [])
#    }
#  }
#}


#output "nodegroup_launch_templates" {
#  value = {
#    for nodegroup_name, info in data.aws_eks_node_group.nodegroup_information :
#    nodegroup_name => info.launch_template
#  }
#}

#output "nodegroup_information" {
#  value = data.aws_eks_node_group.nodegroup_information
#}

#output "launch_template_arns" {
#  value = { for k, v in data.aws_launch_template.nodegroup_lt : k => v.id }
#}




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

resource "aws_iam_role_policy_attachment" "attach_AmazonSSMManagedInstanceCore" {
  for_each   = toset(var.karpenter_role_attatchments)
  role       = aws_iam_role.karpenter_node_trust_role.name
  policy_arn = each.value
}


resource "aws_iam_role" "karpenter_conroller_role" {
  name = "KarpenterControllerRole-${var.cluster_name}"

  assume_role_policy = jsonencode({
    Version : "2012-10-17",
    Statement = [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Federated" : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${local.oidc_provider}"
        },
        "Action" : "sts:AssumeRoleWithWebIdentity",
        "Condition" : {
          "StringEquals" : {
            "${local.oidc_provider}:aud" : "sts.amazonaws.com",
            "${local.oidc_provider}:sub" : "system:serviceaccount:${var.karpenter_namespace_name}:karpenter"
          }
        }
      }
    ]
  })
}


resource "aws_iam_policy" "controller_policy" {
  name        = "KarpenterControllerPolicy-${var.cluster_name}"
  description = "controller policy for karpenter"

  policy = jsonencode({
    Version : "2012-10-17",
    Statement = [
      {
        "Action" : [
          "ssm:GetParameter",
          "ec2:DescribeImages",
          "ec2:RunInstances",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeInstanceTypeOfferings",
          "ec2:DeleteLaunchTemplate",
          "ec2:CreateTags",
          "ec2:CreateLaunchTemplate",
          "ec2:CreateFleet",
          "ec2:DescribeSpotPriceHistory",
          "pricing:GetProducts"
        ],
        "Effect" : "Allow",
        "Resource" : "*",
        "Sid" : "Karpenter"
      },
      {
        "Action" : "ec2:TerminateInstances",
        "Condition" : {
          "StringLike" : {
            "ec2:ResourceTag/karpenter.sh/nodepool" : "*"
          }
        },
        "Effect" : "Allow",
        "Resource" : "*",
        "Sid" : "ConditionalEC2Termination"
      },
      {
        "Effect" : "Allow",
        "Action" : "iam:PassRole",
        "Resource" : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/KarpenterNodeRole-${var.cluster_name}",
        "Sid" : "PassNodeIAMRole"
      },
      {
        "Effect" : "Allow",
        "Action" : "eks:DescribeCluster",
        "Resource" : "arn:aws:eks:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:cluster/${var.cluster_name}",
        "Sid" : "EKSClusterEndpointLookup"
      },
      {
        "Sid" : "AllowScopedInstanceProfileCreationActions",
        "Effect" : "Allow",
        "Resource" : "*",
        "Action" : [
          "iam:CreateInstanceProfile"
        ],
        "Condition" : {
          "StringEquals" : {
            "aws:RequestTag/kubernetes.io/cluster/${var.cluster_name}" : "owned",
            "aws:RequestTag/topology.kubernetes.io/region" : "${data.aws_region.current.name}"
          },
          "StringLike" : {
            "aws:RequestTag/karpenter.k8s.aws/ec2nodeclass" : "*"
          }
        }
      },
      {
        "Sid" : "AllowScopedInstanceProfileTagActions",
        "Effect" : "Allow",
        "Resource" : "*",
        "Action" : [
          "iam:TagInstanceProfile"
        ],
        "Condition" : {
          "StringEquals" : {
            "aws:ResourceTag/kubernetes.io/cluster/${var.cluster_name}" : "owned",
            "aws:ResourceTag/topology.kubernetes.io/region" : "${data.aws_region.current.name}",
            "aws:RequestTag/kubernetes.io/cluster/${var.cluster_name}" : "owned",
            "aws:RequestTag/topology.kubernetes.io/region" : "${data.aws_region.current.name}"
          },
          "StringLike" : {
            "aws:ResourceTag/karpenter.k8s.aws/ec2nodeclass" : "*",
            "aws:RequestTag/karpenter.k8s.aws/ec2nodeclass" : "*"
          }
        }
      },
      {
        "Sid" : "AllowScopedInstanceProfileActions",
        "Effect" : "Allow",
        "Resource" : "*",
        "Action" : [
          "iam:AddRoleToInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile",
          "iam:DeleteInstanceProfile"
        ],
        "Condition" : {
          "StringEquals" : {
            "aws:ResourceTag/kubernetes.io/cluster/${var.cluster_name}" : "owned",
            "aws:ResourceTag/topology.kubernetes.io/region" : "${data.aws_region.current.name}"
          },
          "StringLike" : {
            "aws:ResourceTag/karpenter.k8s.aws/ec2nodeclass" : "*"
          }
        }
      },
      {
        "Sid" : "AllowInstanceProfileReadActions",
        "Effect" : "Allow",
        "Resource" : "*",
        "Action" : "iam:GetInstanceProfile"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_policy-conroller" {
  role       = aws_iam_role.karpenter_conroller_role.name
  policy_arn = aws_iam_policy.controller_policy.arn
}

# Tag the subnets for each node group
resource "aws_ec2_tag" "karpenter_discovery" {
  for_each    = toset(data.aws_eks_node_groups.nodegroup.names)
  resource_id = each.value
  key         = "karpenter.sh/discovery"
  value       = var.cluster_name
}

# Tagging the security groups that are assoicated with the current asg's
resource "aws_ec2_tag" "karpenter_sg_tag" {
  for_each = {
    for nodegroup_name, asg in data.aws_autoscaling_group.nodegroup_asg :
    nodegroup_name => asg.vpc_zone_identifier
  }

  resource_id = each.value
  key         = "karpenter.sh/discovery"
  value       = var.cluster_name
}

resource "aws_eks_access_entry" "kaprenter_cluster_access" {
  cluster_name  = var.cluster_name
  principal_arn = data.aws_eks_cluster.current.arn
  type          = "EC2_LINUX" # or "EC2_WINDOWS" - Linux covers Bottlerocket as well
  
  tags = { 
    env = "dev" 
  }
}

#Deploy karpenter helm chart
resource "helm_release" "karpenter" {
  name       = "karpenter"
  repository = "oci://public.ecr.aws/karpenter/karpenter"
  version    = var.karpenter_version
  namespace  = var.karpenter_namespace

  create_namespace = var.create_karpenter_namespace

  values = [templatefile("${path.module}/values.yaml", {
    cluster_name= var.cluster_name
    aws_patition = var.aws_partition
    aws_account_id = var.aws_account_id
    nodegroup = var.nodegroup
    aws_account_id = data.aws_caller_identity.current.account_id
  })]
}

resource "kubectl_manifest" "karpenter_crds" {
  for_each = toset([
    "https://raw.githubusercontent.com/aws/karpenter-provider-aws/v${var.karpenter_version}/pkg/apis/crds/karpenter.sh_nodepools.yaml",
    "https://raw.githubusercontent.com/aws/karpenter-provider-aws/v${var.karpenter_version}/pkg/apis/crds/karpenter.k8s.aws_ec2nodeclasses.yaml",
    "https://raw.githubusercontent.com/aws/karpenter-provider-aws/v${var.karpenter_version}/pkg/apis/crds/karpenter.sh_nodeclaims.yaml"
  ])

  yaml_body = file(each.value)
}


