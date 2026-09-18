data "terraform_remote_state" "infrastructure" {
  backend = "s3"

  config = {
    bucket = "aws-eks-terraform-state-bucket"
    key    = "infrastructure/terraform.tfstate"
    region = var.aws_region
  }
}

locals {
  cluster_endpoint       = data.terraform_remote_state.infrastructure.outputs.cluster_endpoint
  cluster_ca_certificate = data.terraform_remote_state.infrastructure.outputs.cluster_ca_certificate
  cluster_name           = data.terraform_remote_state.infrastructure.outputs.cluster_name
  oidc_provider_arn      = data.terraform_remote_state.infrastructure.outputs.oidc_provider_arn
  oidc_provider_url      = data.terraform_remote_state.infrastructure.outputs.oidc_provider_url
  vpc_id                 = data.terraform_remote_state.infrastructure.outputs.vpc_id
}