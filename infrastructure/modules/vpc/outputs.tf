output "task-api-vpc-id" {
  value = aws_vpc.task-api-vpc.id
}

output "task-api-subnet-private-ids" {
  value = [
    aws_subnet.task-api-subnet-private-1a.id,
    aws_subnet.task-api-subnet-private-1b.id
  ]
}

output "task-api-subnet-public-ids" {
  value = [
    aws_subnet.task-api-subnet-public-1a.id,
    aws_subnet.task-api-subnet-public-1b.id
  ]
}

output "task-api-nat-gateway-id" {
  value = aws_nat_gateway.task-api-nat-gateway-1a.id
}

output "task-api-internet-gateway-id" {
  value = aws_internet_gateway.task-api-igw.id
}

output "task-api-eip-id" {
  value = aws_eip.task-api-eip-1a.id
}

