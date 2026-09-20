variable "cluster_name" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "eks_version" {
  type    = string
  default = "1.35"
}

variable "terraform_plan_readonly_role_arn" {
  type = string
}

variable "terraform_apply_role_arn" {
  type = string
}