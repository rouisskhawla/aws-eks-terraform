resource "aws_iam_role" "eso_irsa_role" {
  name = "aws-external-secrets-operator-irsa"

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
        "${local.oidc_provider_url}:sub" = "system:serviceaccount:kube-system:external-secrets" }
      }
    }]
  })
}

resource "aws_iam_role_policy" "eso_irsa_role_policy" {
  name = "eso_irsa_role_policy"
  role = aws_iam_role.eso_irsa_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSecretsManagerAccess"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = local.rds_secret_arn
      },
      {
        Sid      = "KMSDecryptForSecret"
        Effect   = "Allow"
        Action   = "kms:Decrypt"
        Resource = "*"
      }
    ]
  })
}

resource "kubernetes_service_account_v1" "eso_irsa" {
  metadata {
    name      = "external-secrets"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.eso_irsa_role.arn
    }
  }
}

resource "helm_release" "aws_eso" {
  name      = "external-secrets"
  chart     = "${path.module}/charts/external-secrets.tgz"
  namespace = "kube-system"
  atomic    = true
  wait      = true
  timeout   = 600

  set = [
    {
      name  = "serviceAccount.create"
      value = "false"
    },
    {
      name  = "serviceAccount.name"
      value = kubernetes_service_account_v1.eso_irsa.metadata[0].name
    },
    {
      name  = "replicaCount"
      value = "1"
    }
  ]

  depends_on = [
    kubernetes_service_account_v1.eso_irsa,
    aws_iam_role_policy.eso_irsa_role_policy
  ]
}

resource "kubernetes_manifest" "secret_store" {
  manifest = {
    "apiVersion" = "external-secrets.io/v1"
    "kind"       = "ClusterSecretStore"
    "metadata" = {
      "name" = "aws-secretstore"
    }
    spec = {
      provider = {
        aws = {
          service = "SecretsManager"
          region  = var.aws_region

          auth = {
            jwt = {
              serviceAccountRef = {
                name      = "external-secrets"
                namespace = "kube-system"
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    helm_release.aws_eso
  ]
}

resource "kubernetes_manifest" "external_secret" {
  manifest = {
    apiVersion = "external-secrets.io/v1"
    kind       = "ExternalSecret"

    metadata = {
      name      = "rds-credentials"
      namespace = "default"
    }

    spec = {
      refreshInterval = "1h"

      secretStoreRef = {
        name = "aws-secretstore"
        kind = "ClusterSecretStore"
      }

      target = {
        name           = "rds-credentials"
        creationPolicy = "Owner"
        template = {
          engineVersion = "v2"
          data = {
            DATABASE_URL = "postgresql://{{ .username }}:{{ .password }}@${local.db_endpoint}/${local.db_name}"
          }
        }
      }

      data = [
        {
          secretKey = "username"
          remoteRef = {
            key      = local.rds_secret_arn
            property = "username"
          }
        },
        {
          secretKey = "password"
          remoteRef = {
            key      = local.rds_secret_arn
            property = "password"
          }
        }
      ]
    }
  }

  depends_on = [
    kubernetes_manifest.secret_store
  ]
}