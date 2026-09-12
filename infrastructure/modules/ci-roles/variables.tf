variable "oidc_provider_arn" {
  type = string
}

variable "github_repo" {
  type = string
}

variable "github_branch" {
  type    = string
  default = "main"
}

variable "state_bucket_arn" {
  type = string
}