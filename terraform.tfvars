
cluster_name = "dev"

karpenter_role_attatchments = [
  "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
  "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
  "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
  "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
]

karpenter_namespace_name = "karpenter"

create_karpenter_namespace = true

karpenter_subnet_ids = [
  "subnet-002892383563a69a8",
  "subnet-0f93c2d0b60dcfe6a",
  "subnet-06eccff6d67fbd28e"
]