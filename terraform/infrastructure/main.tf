module "ecr" {
  source              = "./modules/ecr"
  ecr_repository_name = var.ecr_repository_name
}

module "vpc" {
  source                 = "./modules/vpc"
  aws_availability_zones = var.aws_availability_zones
  cluster_name           = var.cluster_name
}

module "eks" {
  source       = "./modules/eks"
  cluster_name = var.cluster_name
  subnet_ids = concat(
    module.vpc.private_subnets_ids,
    module.vpc.public_subnets_ids
  )
  private_subnet_ids               = module.vpc.private_subnets_ids
  terraform_plan_readonly_role_arn = local.terraform_plan_readonly_role_arn
  terraform_apply_role_arn         = local.terraform_apply_role_arn
}