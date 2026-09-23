# IAM OIDC provider for GitHub Actions

data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com/.well-known/openid-configuration"
}

resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]

  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]
}

resource "aws_iam_role" "github_actions_role" {
  name = var.role_name
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
        "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:ref:refs/heads/${var.github_branch}" }
      }
    }]
  })
}

resource "aws_iam_role_policy" "github_actions_policy" {
  name = "${var.role_name}-ecr-push"
  role = aws_iam_role.github_actions_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowECRAccess"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowECRPush"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = var.ecr_repository_arn
      }
    ]
  })
}


# Terrraform Plan Read Only Role for GitHub Actions 

resource "aws_iam_role" "terraform_plan_readonly" {
  name = "terraform-plan-readonly"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:ref:refs/heads/${var.github_branch}"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "terraform_plan_readonly_policy" {
  name = "terraform-plan-readonly-policy"
  role = aws_iam_role.terraform_plan_readonly.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "IAMReadOnly"
        Effect = "Allow"
        Action = [
          "iam:Get*",
          "iam:List*"
        ]
        Resource = "*"
      },
      {
        Sid    = "ECRReadOnly"
        Effect = "Allow"
        Action = [
          "ecr:Describe*",
          "ecr:Get*",
          "ecr:List*"
        ]
        Resource = "*"
      },
      {
        Sid    = "S3ReadOnly"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          var.state_bucket_arn,
          "${var.state_bucket_arn}/*",
        ]
      },
      {
        Sid    = "S3LockFile"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${var.state_bucket_arn}/*.tflock"
      },
      {
        Sid    = "EC2ReadOnly"
        Effect = "Allow"
        Action = [
          "ec2:Describe*"
        ]
        Resource = "*"
      },
      {
        Sid    = "EKSReadOnly"
        Effect = "Allow"
        Action = [
          "eks:Describe*",
          "eks:List*"
        ],
        Resource = "*"
      },
      {
        Sid    = "RDSReadOnly"
        Effect = "Allow"
        Action = [
          "rds:Describe*",
          "rds:List*",
          "secretsmanager:Describe*",
        ],
        Resource = "*"
      }
    ]
  })
}

# Terrraform Apply Role for GitHub Actions

resource "aws_iam_role" "terraform_apply" {
  name = "terraform-apply"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:environment:${var.environment_name}"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "terraform_apply_policy" {
  name = "terraform-apply-policy"
  role = aws_iam_role.terraform_apply.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadOnlyServices"
        Effect = "Allow"
        Action = [
          "ec2:Describe*",
          "eks:Describe*",
          "eks:List*",
          "iam:Get*",
          "ecr:Get*",
          "iam:List*",
          "ecr:Describe*",
          "ecr:List*",
          "rds:Describe*",
          "rds:List*",
          "secretsmanager:Describe*",

        ]
        Resource = "*"
      },
      {
        Sid    = "IAM"
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:CreateOpenIDConnectProvider",
          "iam:DeleteOpenIDConnectProvider",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:UpdateAssumeRolePolicy"
        ]
        Resource = "*"
      },
      {
        Sid    = "ECR"
        Effect = "Allow"
        Action = [
          "ecr:CreateRepository",
          "ecr:DeleteRepository",
          "ecr:PutLifecyclePolicy",
          "ecr:DeleteLifecyclePolicy",
          "ecr:TagResource",
          "ecr:UntagResource"
        ]
        Resource = "*"
      },
      {
        Sid    = "S3"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          var.state_bucket_arn,
          "${var.state_bucket_arn}/*"
        ]
      },
      {
        Sid    = "EC2"
        Effect = "Allow"
        Action = [
          "ec2:CreateVpc",
          "ec2:DeleteVpc",
          "ec2:ModifyVpcAttribute",
          "ec2:CreateSubnet",
          "ec2:DeleteSubnet",
          "ec2:ModifySubnetAttribute",
          "ec2:CreateInternetGateway",
          "ec2:DeleteInternetGateway",
          "ec2:AttachInternetGateway",
          "ec2:DetachInternetGateway",
          "ec2:CreateNatGateway",
          "ec2:DeleteNatGateway",
          "ec2:AllocateAddress",
          "ec2:ReleaseAddress",
          "ec2:CreateRouteTable",
          "ec2:DeleteRouteTable",
          "ec2:CreateRoute",
          "ec2:ReplaceRoute",
          "ec2:DeleteRoute",
          "ec2:AssociateRouteTable",
          "ec2:DisassociateRouteTable",
          "ec2:CreateTags",
          "ec2:DeleteTags",
          "ec2:CreateSecurityGroup",
          "ec2:DeleteSecurityGroup",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupEgress",
          "ec2:DisassociateAddress"
        ]
        Resource = "*"
      },
      {
        Sid    = "EKS"
        Effect = "Allow"
        Action = [
          "eks:CreateCluster",
          "eks:DeleteCluster",
          "eks:UpdateClusterConfig",
          "eks:UpdateClusterVersion",
          "eks:CreateNodegroup",
          "eks:DeleteNodegroup",
          "eks:UpdateNodegroupConfig",
          "eks:UpdateNodegroupVersion",
          "eks:TagResource",
          "eks:UntagResource"
        ]
        Resource = "*"
      },
      {
        Sid    = "PassEKSRoles"
        Effect = "Allow"
        Action = "iam:PassRole"
        Resource = [
          "${var.eks_node_role_arn}",
          "${var.eks_cluster_role_arn}"
        ],
        Condition = {
          StringEquals = {
            "iam:PassedToService" = "eks.amazonaws.com"
          }
        }
      },
      {
        Sid      = "AllowCreateServiceLinkedRoles"
        Effect   = "Allow"
        Action   = "iam:CreateServiceLinkedRole"
        Resource = "*"
        Condition = {
          StringEquals = {
            "iam:AWSServiceName" = [
              "eks.amazonaws.com",
              "eks-nodegroup.amazonaws.com",
              "rds.amazonaws.com"
            ]
          }
        }
      },
      {
        Sid    = "EKSAccessEntries"
        Effect = "Allow"
        Action = [
          "eks:CreateAccessEntry",
          "eks:DeleteAccessEntry",
          "eks:AssociateAccessPolicy",
          "eks:DisassociateAccessPolicy",
        ]
        Resource = "*"
      },
      {
        Sid    = "RDS"
        Effect = "Allow"
        Action = [
          "rds:CreateDBInstance",
          "rds:DeleteDBInstance",
          "rds:ModifyDBInstance",
          "rds:CreateDBSubnetGroup",
          "rds:DeleteDBSubnetGroup",
          "rds:AddTagsToResource",
          "secretsmanager:CreateSecret",
          "secretsmanager:DeleteSecret",
          "secretsmanager:GetSecretValue",
          "secretsmanager:PutSecretValue",
          "secretsmanager:TagResource",
        ]
        Resource = "*"
      },
      {
        Sid    = "KMSForSecretsManager"
        Effect = "Allow"
        Action = [
          "kms:CreateGrant",
          "kms:DescribeKey",
        ]
        Resource = "*"
      }
    ]
  })
}