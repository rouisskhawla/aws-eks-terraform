resource "aws_vpc" "task-api-vpc" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_internet_gateway" "task-api-igw" {
  vpc_id = aws_vpc.task-api-vpc.id
}

resource "aws_subnet" "task-api-subnet-private-1a" {
  vpc_id            = aws_vpc.task-api-vpc.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = var.aws_availability_zones[0]
  tags = {
    Name                                        = "task-api-subnet-private-1a"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = "1"
  }
}

resource "aws_subnet" "task-api-subnet-private-1b" {
  vpc_id            = aws_vpc.task-api-vpc.id
  cidr_block        = "10.0.12.0/24"
  availability_zone = var.aws_availability_zones[1]
  tags = {
    Name                                        = "task-api-subnet-private-1b"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = "1"
  }

}

resource "aws_subnet" "task-api-subnet-public-1a" {
  vpc_id                  = aws_vpc.task-api-vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = var.aws_availability_zones[0]
  map_public_ip_on_launch = true
  tags = {
    Name                                        = "task-api-subnet-public-1a"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = "1"
  }
}

resource "aws_subnet" "task-api-subnet-public-1b" {
  vpc_id                  = aws_vpc.task-api-vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = var.aws_availability_zones[1]
  map_public_ip_on_launch = true
  tags = {
    Name                                        = "task-api-subnet-public-1b"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = "1"
  }
}

resource "aws_eip" "task-api-eip-1a" {
  domain = "vpc"
}

resource "aws_nat_gateway" "task-api-nat-gateway-1a" {
  subnet_id     = aws_subnet.task-api-subnet-public-1a.id
  allocation_id = aws_eip.task-api-eip-1a.id
}

resource "aws_route_table" "task-api-public-route-table" {
  vpc_id = aws_vpc.task-api-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.task-api-igw.id
  }
}

resource "aws_route_table" "task-api-private-route-table" {
  vpc_id = aws_vpc.task-api-vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.task-api-nat-gateway-1a.id
  }
}

resource "aws_route_table_association" "task-api-public-route-table-association-1a" {
  subnet_id      = aws_subnet.task-api-subnet-public-1a.id
  route_table_id = aws_route_table.task-api-public-route-table.id
}

resource "aws_route_table_association" "task-api-public-route-table-association-1b" {
  subnet_id      = aws_subnet.task-api-subnet-public-1b.id
  route_table_id = aws_route_table.task-api-public-route-table.id
}

resource "aws_route_table_association" "task-api-private-route-table-association-1a" {
  subnet_id      = aws_subnet.task-api-subnet-private-1a.id
  route_table_id = aws_route_table.task-api-private-route-table.id
}

resource "aws_route_table_association" "task-api-private-route-table-association-1b" {
  subnet_id      = aws_subnet.task-api-subnet-private-1b.id
  route_table_id = aws_route_table.task-api-private-route-table.id
}