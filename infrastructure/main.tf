module "iam_oidc_github" {
  source             = "./modules/iam-oidc-github"
  github_repo        = var.github_repo
  github_branch      = var.github_branch
  ecr_repository_arn = module.ecr.repository_arn
}

module "ecr" {
  source              = "./modules/ecr"
  ecr_repository_name = var.ecr_repository_name

}

module "ci_roles" {
  source            = "./modules/ci-roles"
  github_repo       = var.github_repo
  github_branch     = var.github_branch
  environment_name  = var.environment_name
  oidc_provider_arn = module.iam_oidc_github.oidc_provider_arn
  state_bucket_arn  = "arn:aws:s3:::aws-eks-terraform-state-bucket"
}