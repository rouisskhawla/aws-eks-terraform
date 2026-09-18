resource "github_actions_variable" "plan_role_arn" {
  repository    = "aws-eks-terraform"
  variable_name = "TERRAFORM_PLAN_ROLE_ARN"
  value         = aws_iam_role.terraform_plan_readonly.arn
}

resource "github_actions_environment_variable" "apply_role_arn" {
  repository    = "aws-eks-terraform"
  environment   = var.environment_name
  variable_name = "TERRAFORM_APPLY_ROLE_ARN"
  value         = aws_iam_role.terraform_apply.arn
}
