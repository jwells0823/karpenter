

terraform {
  backend "s3" {
    bucket = "your-bucket"
    key    = "not-sure-if-necessary"
    region = "us-east-1"
  }
}

