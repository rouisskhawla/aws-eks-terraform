# Configure AWS CLI with iam user's access key
aws configure 

# Verify identity
aws sts get-caller-identity 

# Manually create s3 bucket for terraform state file
aws s3 mb s3://aws-eks-terraform-state-bucket

# Init terraform backend 
terraform init

# Format
terraform fmt --recursive 

# Policies for iam user 'terraform-iam-user'
Added these permission to iam user in order to be able to Apply both infrastructure and GitHub-actions-oidc with iam user locally 

AWS managed:
AmazonEC2ContainerRegistryFullAccess
AmazonEC2FullAccess
AmazonEKSClusterPolicy

and created inline policies for each service :

{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "sts:GetCallerIdentity",
            "Resource": "*"
        }
    ]
}

{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "Statement1",
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:ListBucket",
                "s3:PutObject",
                "s3:DeleteObject"
            ],
            "Resource": [
                "arn:aws:s3:::aws-eks-terraform-state-bucket",
                "arn:aws:s3:::aws-eks-terraform-state-bucket/*",
            ]
        }
    ]
}

{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "IAMRoleManagement",
            "Effect": "Allow",
            "Action": [
                "iam:CreateRole",
                "iam:DeleteRole",
                "iam:GetRole",
                "iam:UpdateRole",
                "iam:TagRole",
                "iam:UntagRole",
                "iam:AttachRolePolicy",
                "iam:DetachRolePolicy",
                "iam:ListAttachedRolePolicies",
                "iam:ListRolePolicies",
                "iam:PutRolePolicy",
                "iam:ListInstanceProfilesForRole",
                "iam:DeleteServiceLinkedRole",
                "iam:GetServiceLinkedRoleDeletionStatus",
                "iam:GetRolePolicy",
                "iam:DeleteRolePolicy",
                "iam:UpdateAssumeRolePolicy"
            ],
            "Resource": "*"
        },
        {
            "Sid": "OIDCProviderManagement",
            "Effect": "Allow",
            "Action": [
                "iam:CreateOpenIDConnectProvider",
                "iam:DeleteOpenIDConnectProvider",
                "iam:GetOpenIDConnectProvider",
                "iam:TagOpenIDConnectProvider",
                "iam:UpdateOpenIDConnectProviderThumbprint",
                "iam:UntagOpenIDConnectProvider"
            ],
            "Resource": "*"
        },
        {
            "Sid": "PassEKSRoles",
            "Effect": "Allow",
            "Action": [
                "iam:PassRole"
            ],
            "Resource": [
                "arn:aws:iam::558073272056:role/aws-eks-terraform-eks-cluster-role",
                "arn:aws:iam::558073272056:role/aws-eks-terraform-eks-node-role"
            ],
            "Condition": {
                "StringEquals": {
                    "iam:PassedToService": "eks.amazonaws.com"
                }
            }
        },
        {
            "Sid": "AllowLocalUserCreateSLR",
            "Effect": "Allow",
            "Action": "iam:CreateServiceLinkedRole",
            "Resource": "*",
            "Condition": {
                "StringEquals": {
                    "iam:AWSServiceName": [
                        "eks.amazonaws.com",
						"eks-nodegroup.amazonaws.com"
                    ]
                }
            }
        }
    ]
}

{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "eks:CreateCluster",
                "eks:DeleteCluster",
                "eks:DescribeCluster",
                "eks:UpdateClusterConfig",
                "eks:UpdateClusterVersion",
                "eks:CreateNodegroup",
                "eks:DeleteNodegroup",
                "eks:DescribeNodegroup",
                "eks:UpdateNodegroupConfig",
                "eks:UpdateNodegroupVersion",
                "eks:ListClusters",
                "eks:ListNodegroups",
                "eks:TagResource",
                "eks:UntagResource"
            ],
            "Resource": "*"
        }
    ]
}



# GitHub Fine-Grained PAT

Create a **Fine-grained personal access token** with:

**Repository access**

* Only select repositories
* `rouisskhawla/aws-eks-terraform`

**Repository permissions**

* **Actions:** Read and write
* **Environments:** Read and write
* **Variables:** Read and write
* **Metadata:** Read-only (automatically required)

Then copy the token and set it locally:

```bash
export GITHUB_TOKEN="github_pat_..."
```

# Cluster Health

## Verify that AWS CLI is authenticated first:

```bash
aws sts get-caller-identity
```

## Use AWS CLI to configure `kubectl` access, then use `kubectl`.

```bash
aws eks update-kubeconfig --region us-east-1 --name aws-eks-terraform
```

## Verify if the Cluster is Ready :

```bash
kubectl get nodes 
```

## Check running pods for all namespaces:

```bash
kubectl get pods -A
```

## For the AWS Load Balancer Controller specifically:

```bash
kubectl get pods -n kube-system
```

## And verify the EKS cluster:

```bash
aws eks describe-cluster --region us-east-1 --name aws-eks-terraform
```

## Verify the controller deployment nd pods:

```bash
kubectl get deployment -n kube-system aws-load-balancer-controller
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
```

## Verify the ServiceAccount / IRSA

```bash
kubectl get serviceaccount aws-load-balancer-controller -n kube-system -o yaml
```

## Check controller logs

```bash
kubectl logs -n kube-system deployment/aws-load-balancer-controller
```
