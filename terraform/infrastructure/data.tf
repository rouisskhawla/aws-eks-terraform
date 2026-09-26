data "terraform_remote_state" "github_actions_oidc" {
  backend = "s3"

  config = {
    bucket = "aws-eks-terraform-state-bucket"
    key    = "github-actions-oidc/terraform.tfstate"
    region = var.aws_region
  }
}

locals {
  terraform_plan_readonly_role_arn = data.terraform_remote_state.github_actions_oidc.outputs.plan_role_arn
  terraform_apply_role_arn         = data.terraform_remote_state.github_actions_oidc.outputs.apply_role_arn
  deploy_role_arn                  = data.terraform_remote_state.github_actions_oidc.outputs.deploy_role_arn
}