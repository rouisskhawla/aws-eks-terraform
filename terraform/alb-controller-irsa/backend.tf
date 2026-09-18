terraform {
  backend "s3" {
    bucket       = "aws-eks-terraform-state-bucket"
    key          = "alb-controller-irsa/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }
}