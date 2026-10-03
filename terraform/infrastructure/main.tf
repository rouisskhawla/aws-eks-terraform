module "ecr" {
  source              = "./modules/ecr"
  ecr_repository_name = var.ecr_repository_name
}

resource "github_actions_variable" "ecr_repository_uri" {
  repository    = "aws-eks-terraform"
  variable_name = "ECR_REPOSITORY_URI"
  value         = module.ecr.repository_url
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
  deploy_role_arn                  = local.deploy_role_arn
}

module "rds" {
  source             = "./modules/rds"
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnets_ids
  eks_node_sg_id     = module.eks.cluster_security_group_id
}

module "alarms" {
  source          = "./modules/alarms"
  alarm_email     = var.alarm_email
  rds_instance_id = module.rds.db_instance_id
  cluster_name    = var.cluster_name
}