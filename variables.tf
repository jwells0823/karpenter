

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
