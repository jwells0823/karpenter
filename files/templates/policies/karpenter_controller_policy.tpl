{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
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
      "Resource": "*",
      "Sid": "Karpenter"
    },
    {
      "Effect": "Allow",
      "Action": "ec2:TerminateInstances",
      "Condition": {
        "StringLike": {
          "ec2:ResourceTag/karpenter.sh/nodepool": "*"
        }
      },
      "Resource": "*",
      "Sid": "ConditionalEC2Termination"
    },
    {
      "Effect": "Allow",
      "Action": "iam:PassRole",
      "Resource": "arn:aws:iam::${account_id}:role/KarpenterNodeRole-${cluster_name}",
      "Sid": "PassNodeIAMRole"
    },
    {
      "Effect": "Allow",
      "Action": "eks:DescribeCluster",
      "Resource": "arn:aws:eks:${aws_region}:${account_id}:cluster/${cluster_name}",
      "Sid": "EKSClusterEndpointLookup"
    },
    {
      "Sid": "AllowScopedInstanceProfileCreationActions",
      "Effect": "Allow",
      "Resource": "*",
      "Action": [
        "iam:CreateInstanceProfile"
      ],
      "Condition": {
        "StringEquals": {
          "aws:RequestTag/kubernetes.io/cluster/${cluster_name}": "owned",
          "aws:RequestTag/topology.kubernetes.io/region": "${aws_region}"
        },
        "StringLike": {
          "aws:RequestTag/karpenter.k8s.aws/ec2nodeclass": "*"
        }
      }
    },
    {
      "Sid": "AllowScopedInstanceProfileTagActions",
      "Effect": "Allow",
      "Resource": "*",
      "Action": [
        "iam:TagInstanceProfile"
      ],
      "Condition": {
        "StringEquals": {
          "aws:ResourceTag/kubernetes.io/cluster/${cluster_name}": "owned",
          "aws:ResourceTag/topology.kubernetes.io/region": "${aws_region}",
          "aws:RequestTag/kubernetes.io/cluster/${cluster_name}": "owned",
          "aws:RequestTag/topology.kubernetes.io/region": "${aws_region}"
        },
        "StringLike": {
          "aws:ResourceTag/karpenter.k8s.aws/ec2nodeclass": "*",
          "aws:RequestTag/karpenter.k8s.aws/ec2nodeclass": "*"
        }
      }
    },
    {
      "Sid": "AllowScopedInstanceProfileActions",
      "Effect": "Allow",
      "Resource": "*",
      "Action": [
        "iam:AddRoleToInstanceProfile",
        "iam:RemoveRoleFromInstanceProfile",
        "iam:DeleteInstanceProfile"
      ],
      "Condition": {
        "StringEquals": {
          "aws:ResourceTag/kubernetes.io/cluster/${cluster_name}": "owned",
          "aws:ResourceTag/topology.kubernetes.io/region": "${aws_region}"
        },
        "StringLike": {
          "aws:ResourceTag/karpenter.k8s.aws/ec2nodeclass": "*"
        }
      }
    },
    {
      "Sid": "AllowInstanceProfileReadActions",
      "Effect": "Allow",
      "Resource": "*",
      "Action": "iam:GetInstanceProfile"
    },
    {
      "Effect": "Allow",
      "Action": [
        "iam:GetRole",
        "iam:ListInstanceProfiles"
      ],
      "Resource": "arn:aws:iam::${account_id}:role/KarpenterNodeRole-${cluster_name}"
    }
  ]
}

