output "db_endpoint" {
  value = aws_db_instance.task_api_db.endpoint
}

output "db_port" {
  value = aws_db_instance.task_api_db.port
}


output "db_name" {
  value = aws_db_instance.task_api_db.db_name
}

output "master_user_secret_arn" {
  value = aws_db_instance.task_api_db.master_user_secret[0].secret_arn
}
