output "ecr_repository_url" {
  value = module.ecr.repository_url
}

output "task-api-vpc-id" {
  value = module.vpc.task-api-vpc-id
}

output "task-api-subnet-private-ids" {
  value = module.vpc.task-api-subnet-private-ids
}

output "task-api-subnet-public-ids" {
  value = module.vpc.task-api-subnet-public-ids
}

output "task-api-nat-gateway-id" {
  value = module.vpc.task-api-nat-gateway-id
}

output "task-api-internet-gateway-id" {
  value = module.vpc.task-api-internet-gateway-id
}

output "task-api-eip-id" {
  value = module.vpc.task-api-eip-id
}

