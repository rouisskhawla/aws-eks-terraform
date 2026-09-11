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