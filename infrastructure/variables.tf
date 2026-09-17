variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "github_repo" {
  type    = string
  default = "rouisskhawla@38538299/aws-eks-terraform@1364055098"
}

variable "github_branch" {
  type    = string
  default = "main"
}

variable "environment_name" {
  type    = string
  default = "infra-apply"
}

variable "ecr_repository_name" {
  type    = string
  default = "aws-eks-terraform"
}

variable "state_bucket_name" {
  type    = string
  default = "aws-eks-terraform-state"
}

variable "aws_availability_zones" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b"]
}

variable "cluster_name" {
  description = "Aws cluster name"
  type        = string
  default     = "aws-eks-terraform"
}
