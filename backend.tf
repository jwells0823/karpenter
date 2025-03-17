

terraform {
  backend "s3" {
    bucket = "kterraform-dev"
    key    = "dev/cluster-karpenter"
    region = "us-east-1"
  }
}

