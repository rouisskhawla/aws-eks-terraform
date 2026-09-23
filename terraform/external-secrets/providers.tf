terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.65.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "3.2.1"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "3.3.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "3.6.2"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

provider "kubernetes" {
  host                   = local.cluster_endpoint
  cluster_ca_certificate = base64decode(local.cluster_ca_certificate)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes = {
    host                   = local.cluster_endpoint
    cluster_ca_certificate = base64decode(local.cluster_ca_certificate)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

data "aws_eks_cluster_auth" "this" {
  name = local.cluster_name
}