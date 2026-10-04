variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "repo_url" {
  type    = string
  default = "https://github.com/rouisskhawla/aws-eks-terraform"
}

variable "branch_name" {
  type    = string
  default = "main"
}