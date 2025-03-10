

terraform {
  backend "s3" {
    bucket = "your_bucketv"
    key    = "your_key"
    region = "your_region"
  }
}

