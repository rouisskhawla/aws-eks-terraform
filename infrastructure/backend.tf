terraform {
  backend "s3" {
    bucket       = "aws-eks-terraform-state-bucket"
    key          = "infrastructure/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }
}