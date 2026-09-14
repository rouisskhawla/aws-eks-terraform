variable "role_name" {
  type    = string
  default = "github-actions-role"
}

variable "github_repo" {
  type    = string
  default = "rouisskhawla@38538299/aws-eks-terraform@1364055098"
}

variable "github_branch" {
  type    = string
  default = "main"
}

variable "ecr_repository_arn" {
  type = string
}