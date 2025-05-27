terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.19.0"
    }
  }
  backend "s3" {
    bucket    = "capstone-terraform-state"
    key       = "terraform/state"
    region    = "eu-north-1"
    use_lockfile = true
  }
}

provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region     = var.aws_region
}