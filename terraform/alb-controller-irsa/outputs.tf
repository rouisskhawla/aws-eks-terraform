output "irsa_role_arn" {
  value = aws_iam_role.alb_controller_irsa_role.arn
}

output "service_account_name" {
  value = kubernetes_service_account_v1.alb_controller_irsa.metadata[0].name
}
