output "ecr_repository_url" {
  value = module.ecr.repository_url
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "private_subnets_ids" {
  value = module.vpc.private_subnets_ids
}

output "public_subnets_ids" {
  value = module.vpc.public_subnets_ids
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_ca_certificate" {
  value     = module.eks.cluster_ca_certificate
  sensitive = true
}

output "oidc_provider_url" {
  value = module.eks.oidc_provider_url
}

output "oidc_provider_arn" {
  value = module.eks.oidc_provider_arn
}

output "cluster_name" {
  value = module.eks.cluster_name
}
