resource "aws_db_subnet_group" "task_api_db_subnet_group" {
  name       = "task-api-db-subnet-group"
  subnet_ids = var.private_subnet_ids
}

resource "aws_security_group" "task_api_rds_sg" {
  name   = "task_api_rds_sg"
  vpc_id = var.vpc_id

  ingress {
    protocol        = "tcp"
    from_port       = 5432
    to_port         = 5432
    security_groups = [var.eks_node_sg_id]

  }
  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "task_api_db" {
  allocated_storage           = 20
  identifier                  = "task-api-db"
  db_name                     = "taskdb"
  engine                      = "postgres"
  engine_version              = "16"
  instance_class              = "db.t4g.micro"
  storage_type                = "gp3"
  username                    = "taskapi"
  db_subnet_group_name        = aws_db_subnet_group.task_api_db_subnet_group.name
  vpc_security_group_ids      = [aws_security_group.task_api_rds_sg.id]
  manage_master_user_password = true
  skip_final_snapshot         = true
  deletion_protection         = false
  publicly_accessible         = false
}
