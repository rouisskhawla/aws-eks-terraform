resource "aws_iam_role" "alb_controller_irsa_role" {
  name = "aws-load-balancer-controller-irsa"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = local.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_provider_url}:aud" = "sts.amazonaws.com"
        }
        StringLike = {
        "${local.oidc_provider_url}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller" }
      }
    }]
  })
}

data "http" "alb_iam_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json"
}

resource "aws_iam_role_policy" "eks_rsa_role_policy" {
  name   = "eks_rsa_role_policy"
  role   = aws_iam_role.alb_controller_irsa_role.id
  policy = data.http.alb_iam_policy.response_body
}

resource "kubernetes_service_account_v1" "alb_controller_irsa" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.alb_controller_irsa_role.arn
    }
  }
}

resource "helm_release" "aws_load_balancer_controller" {
  name      = "aws-load-balancer-controller"
  chart     = "${path.module}/charts/aws-load-balancer-controller.tgz"
  namespace = "kube-system"

  set = [
    {
      name  = "clusterName"
      value = local.cluster_name
    },
    {
      name  = "serviceAccount.create"
      value = "false"
    },
    {
      name  = "serviceAccount.name"
      value = kubernetes_service_account_v1.alb_controller_irsa.metadata[0].name
    },
    {
      name  = "region"
      value = var.aws_region
    },
    {
      name  = "vpcId"
      value = local.vpc_id
    },
    {
      name  = "replicaCount"
      value = "1"
    }
  ]

  depends_on = [
    kubernetes_service_account_v1.alb_controller_irsa,
    aws_iam_role_policy.eks_rsa_role_policy
  ]
}