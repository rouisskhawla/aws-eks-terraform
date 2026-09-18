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