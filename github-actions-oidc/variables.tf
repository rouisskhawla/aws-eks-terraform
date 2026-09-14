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

variable "role_name" {
  type    = string
  default = "github-actions-role"
}

variable "ecr_repository_arn" {
  type    = string
  default = "arn:aws:ecr:us-east-1:558073272056:repository/aws-eks-terraform"
}

variable "state_bucket_arn" {
  type    = string
  default = "arn:aws:s3:::aws-eks-terraform-state-bucket"
}