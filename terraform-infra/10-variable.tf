variable "env" {
  default = "testing"
}
variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
}
variable "aws_region" {
  type = string
}
variable "aws_profile" {
  description = "AWS CLI/SDK profile the aws provider should use. Leave null to fall back to the ambient credential chain (AWS_PROFILE env var, default profile, etc.)."
  type        = string
  default     = null
}
variable "vpc_cidr_block" {
  description = "CIDR (Classless Inter-Domain Routing)."
  type        = string
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
variable "k8s_master_instance_type" {
  type    = string
  default = "t2.medium"
}
variable "k8s_worker_instance_count" {
  type    = number
  default = 2
}
variable "ports" {
  description = "Master-only ports (SSH, Kubernetes API). Worker app ports are exposed via the ALB, see alb_path_routes."
  type        = list(number)
  default     = [22, 6443]
}

variable "permissions_boundary_arn" {
  description = "Optional IAM permissions boundary ARN to attach to the EC2 instance role. Leave null unless your account requires one."
  type        = string
  default     = null
}

variable "alb_path_routes" {
  description = "ALB path-based routing: URL path pattern -> backend NodePort on the k8s workers, e.g. { \"/grafana*\" = 30300 }"
  type        = map(number)
  default     = {}
}
variable "k8s_worker_instance_type" {
  type    = string
  default = "t2.micro"
}