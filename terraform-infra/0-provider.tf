terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.19.0"
    }
  }
  # bucket/region are supplied at `terraform init` time via -backend-config
  # (see backend.hcl.example) since backend blocks cannot read variables or tfvars.
  backend "s3" {
    key = "terraform/aws-infra-state"
  }
}

provider "aws" {
  region = var.aws_region
}