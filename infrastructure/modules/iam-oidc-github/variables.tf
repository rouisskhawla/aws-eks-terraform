variable "role_name" {
  type    = string
  default = "github-actions-role"
}

variable "github_repo" {
  type    = string
  default = "rouisskhawla/aws-eks-terraform"
}

variable "github_branch" {
  type    = string
  default = "main"
}

variable "ecr_repository_arn" {
  type = string
}