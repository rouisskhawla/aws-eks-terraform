output "ecr_repository_url" {
  value = module.ecr.repository_url
}

output "github_actions_role_arn" {
  value = module.iam_oidc_github.role_arn
}

output "plan_role_arn" {
  value = module.ci_roles.plan_role_arn
}

output "apply_role_arn" {
  value = module.ci_roles.apply_role_arn
}
