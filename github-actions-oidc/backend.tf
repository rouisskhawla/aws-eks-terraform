terraform {
  backend "s3" {
    bucket       = "aws-eks-terraform-state-bucket"
    key          = "github-actions-oidc/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }
}