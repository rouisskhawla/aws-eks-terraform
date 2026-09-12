output "plan_role_arn" {
  value = aws_iam_role.terraform_plan_readonly.arn
}

output "apply_role_arn" {
  value = aws_iam_role.terraform_apply.arn
}
