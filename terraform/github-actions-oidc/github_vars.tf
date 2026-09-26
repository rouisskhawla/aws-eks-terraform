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

resource "github_actions_variable" "github_actions_ecr_role_arn" {
  repository    = "aws-eks-terraform"
  variable_name = "ECR_PUSH_ROLE_ARN"
  value         = aws_iam_role.github_actions_ecr_role.arn
}

resource "github_actions_variable" "github_actions_deploy_role_arn" {
  repository    = "aws-eks-terraform"
  variable_name = "APP_DEPLOY_ROLE_ARN"
  value         = aws_iam_role.github_actions_deploy_role.arn
}