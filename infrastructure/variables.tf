variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "github_repo" {
  type    = string
  default = "rouisskhawla/aws-eks-terraform"
}

variable "github_branch" {
  type    = string
  default = "main"
}

variable "ecr_repository_name" {
  type    = string
  default = "aws-eks-terraform"
}

variable "state_bucket_name" {
  type    = string
  default = "aws-eks-terraform-state"
}