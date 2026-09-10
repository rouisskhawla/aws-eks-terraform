variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "github_repo" {
  type    = string
  default = "rouisskhawla/aws-eks-terraform"
}

variable "github_branch" {
  type    = string
  default = "main"
}