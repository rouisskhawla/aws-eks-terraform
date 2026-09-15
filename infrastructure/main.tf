module "ecr" {
  source              = "./modules/ecr"
  ecr_repository_name = var.ecr_repository_name
}

module "vpc" {
  source                 = "./modules/vpc"
  aws_availability_zones = var.aws_availability_zones
  cluster_name           = var.cluster_name
}