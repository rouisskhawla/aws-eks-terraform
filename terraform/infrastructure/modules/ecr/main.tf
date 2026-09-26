resource "aws_ecr_repository" "ecr_repo" {
  name                 = var.ecr_repository_name
  image_tag_mutability = var.image_tag_mutability
  force_delete         = true
  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }
}

resource "aws_ecr_lifecycle_policy" "ecr_repo_policy" {
  repository = aws_ecr_repository.ecr_repo.name

  policy = jsonencode({
    "rules" : [
      {
        "rulePriority" : 1,
        "description" : "Expire images older than ${var.image_expiry_days} days",
        "selection" : {
          "tagStatus" : "untagged",
          "countType" : "sinceImagePushed",
          "countUnit" : "days",
          "countNumber" : var.image_expiry_days
        },
        "action" : {
          "type" : "expire"
        }
      }
    ]
  })
}

resource "github_actions_variable" "ecr_repository_uri" {
  repository    = "aws-eks-terraform"
  variable_name = "ECR_REPOSITORY_URI"
  value         = aws_ecr_repository.ecr_repo.repository_url
}