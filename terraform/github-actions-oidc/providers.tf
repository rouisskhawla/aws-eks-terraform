terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.65.0"
    }

    github = {
      source  = "hashicorp/github"
      version = "6.13.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

provider "github" {
  owner = "rouisskhawla"

}