

variable "cluster_name" {
  type        = string
  default     = "dev"
  description = "This is the name of your cluster"
}

variable "karpenter_namespace_name" {
  type        = string
  default     = "kube-system"
  description = "This is the name of the karpenter namespace"
}

variable "karpenter_role_attatchments" {
  type        = list(string)
  default     = ["arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"]
  description = "The iam roles attatched to karpenter policy, consult documentation for karpenter"
}

variable "node_groups" {
  description = "List of EKS node groups"
  type        = list(string)
  default     = ["node1", "node2"]
}

variable "karpenter_node_group" {
  description = "node group that karpenter runs on"
  type        = list(string)
  default     = ["application"]
}

variable "karpenter_version" {
  description = "karpenter version deployed"
  type        = string
  default     = "1.3.2"
}

variable "karpenter_repository" {
  description = "karpenter repository"
  type        = string
  default     = "oci://public.ecr.aws/karpenter"
}

variable "aws_partition" {
  description = "aws partition (usualy just aws)"
  type        = string
  default     = "aws"
}

variable "karpenter_nodegroup" {
  description = "aws partition (usualy just aws)"
  type        = string
  default     = "application"
}

variable "alias_version" {
  description = "AL2023 alias version for AMI selection"
  type        = string
  default     = "latest"
}

variable "create_karpenter_namespace" {
  description = "create karpenter namespace"
  type        = bool
  default     = false  
}

variable "karpenter_subnet_ids" {
  description = "subnet ids for karpenter"
  type        = list(string)
  default     = ["subnet-1", "subnet-2", "subnet-3"]
}
