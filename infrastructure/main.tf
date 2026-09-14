module "ecr" {
  source              = "./modules/ecr"
  ecr_repository_name = var.ecr_repository_name

}