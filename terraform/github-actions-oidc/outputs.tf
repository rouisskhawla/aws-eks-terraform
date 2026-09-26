output "ecr_role_arn" {
  value = aws_iam_role.github_actions_ecr_role.arn
}

output "plan_role_arn" {
  value = aws_iam_role.terraform_plan_readonly.arn
}

output "apply_role_arn" {
  value = aws_iam_role.terraform_apply.arn
}

output "oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.github.arn
}

output "deploy_role_arn" {
  value = aws_iam_role.github_actions_deploy_role.arn
}