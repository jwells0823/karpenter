

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

variable "karpenter_version" {
  description = "karpenter version deployed"
  type        = string
  default     = "1.3.1"
}

variable "karpenter_repository" {
  description = "karpenter repository"
  type        = string
  default     = "oci://public.ecr.aws/karpenter"
}


