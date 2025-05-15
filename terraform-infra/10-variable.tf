variable "env" {
  default = "testing"
}
variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
}
variable "aws_access_key" {
  type = string
}
variable "aws_secret_key" {
  type = string
}
variable "aws_region" {
  type = string
}
variable "vpc_cidr_block" {
  description = "CIDR (Classless Inter-Domain Routing)."
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "Availability zones for subnets."
  type        = list(string)
}

variable "private_subnets" {
  description = "CIDR ranges for private subnets."
  type        = list(string)
}

variable "public_subnets" {
  description = "CIDR ranges for public subnets."
  type        = list(string)
}
variable "image_name" {
  type    = string
}
variable "image_ami" {
  type    = string
}
variable "k8s_master_instance_type" {
  type    = string
  default = "t2.medium"
}
variable "ports" {
  type    = list(number)
  default = [ 22, 80, 443 ]
}
variable "k8s_worker_instance_type" {
  type    = string
  default = "t2.micro"
}

variable "owner" {
  type        = string
  default = "vkhomenko"
}
variable "project" {
  type        = string 
  default = "capstone"
}
variable "function" {
  type        = string
  default = "k8scluster"
}