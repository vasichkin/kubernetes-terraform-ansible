terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.19.0"
    }
  }
  backend "s3" {
    bucket    = var.aws_s3_bucket
    key       = "terraform/state"
    region    = var.aws_region
    use_lockfile = true
  }
}

provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region     = var.aws_region
}