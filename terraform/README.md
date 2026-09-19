# Terraform, Architecture Overview

This folder contains three **separate Terraform roots**, each with its own state file in S3. They are not one project split into subfolders, they are intentionally isolated because each has a different lifecycle and set of permissions.

```
terraform/
├── github-actions-oidc/     # CI/CD authentication layer
├── infrastructure/          # VPC, EKS cluster, ECR
└── alb-controller-irsa/     # AWS Load Balancer Controller (IRSA + Helm)
```

## Why three separate states

If everything shared a single state, `terraform destroy` on the application infrastructure could also delete the IAM roles GitHub Actions uses to authenticate. Splitting these apart means:

- Destroying/rebuilding the cluster never touches CI's authentication
- A bad `apply` in one root can't corrupt state in another
- Each root can have its own scoped IAM permissions, following least privilege

## The three roots

### 1. `github-actions-oidc/`, authentication layer

Applied **manually, once, locally** using an IAM user, not through the pipeline, since this is what the pipeline itself depends on to exist first.

Manages:
- GitHub's OIDC provider (lets GitHub Actions authenticate to AWS without long-lived credentials)
- `terraform-plan-readonly`, read-only role, used by every `plan` job
- `terraform-apply`, privileged role, used only by `apply` jobs, trust-gated to the `infra-apply` GitHub Environment
- `github-actions-role`, scoped to ECR image push, used by the application's build/push workflow

State key: `github-actions-oidc/terraform.tfstate`

### 2. `infrastructure/`, the actual AWS infrastructure

Applied via the GitHub Actions pipeline: `plan` runs automatically on push to `main`, `apply` waits for manual approval via the `infra-apply` environment.

Manages:
- **VPC**, 2 AZs (EKS requirement), public + private subnets, single NAT Gateway, subnet tags required for EKS/ALB controller discovery
- **EKS cluster**, single node group (1x `t3.small`, Spot capacity), public API endpoint, cluster's own OIDC provider (used by IRSA, separate from GitHub's OIDC provider)
- **ECR**, single repository, immutable tags, scan-on-push, lifecycle policy expiring untagged images

State key: `infrastructure/terraform.tfstate`

### 3. `alb-controller-irsa/`, AWS Load Balancer Controller

Applied via the pipeline, **after** `infrastructure/`, since it depends on the live cluster (OIDC provider, VPC ID, cluster endpoint) via infrastructure's `terraform_remote_state`, this root cannot plan meaningfully until the cluster already exists.

Manages:
- IAM role trusted by the **cluster's** OIDC provider (IRSA), permissioned via AWS's official ALB controller policy
- The `aws-load-balancer-controller` Kubernetes ServiceAccount, annotated to assume that IAM role
- The controller itself, installed via Helm

Once running, this controller watches for Kubernetes `Ingress` resources and automatically provisions real AWS ALBs to match, this is what will let the app actually receive external traffic once deployed.

State key: `alb-controller-irsa/terraform.tfstate`

## Apply order

```
github-actions-oidc/   (manual, local, once, bootstraps everything else)
        │
        ▼
infrastructure/         (pipeline: plan → approval → apply)
        │
        ▼
alb-controller-irsa/    (pipeline: plan → approval → apply, depends on live cluster)
```

The CI/CD pipeline enforces this order automatically: if both `infrastructure/` and `alb-controller-irsa/` change in the same push, the pipeline detects which paths changed and ensures `infrastructure` applies first, `alb-controller-irsa` only proceeds once `infrastructure-apply` has succeeded (or is skipped, if it had no changes to apply).

## Authentication model

Two distinct OIDC trust relationships are in play:

| | Identity | Used by |
|---|---|---|
| **GitHub OIDC** | `repo:owner/repo:ref:...` / `repo:owner/repo:environment:...` | CI/CD pipeline authenticating to AWS |
| **EKS cluster OIDC (IRSA)** | `system:serviceaccount:<namespace>:<name>` | Pods inside the cluster authenticating to AWS |

Both use `sts:AssumeRoleWithWebIdentity` and IAM OIDC providers, but they are two separate providers, trusting two separate token issuers, for two separate purposes.

## CI/CD pipeline summary

- Trigger: push to `main`, path-filtered per root
- `plan` jobs use `terraform-plan-readonly`, read-only, runs unattended
- `apply` jobs use `terraform-apply`, gated behind the `infra-apply` GitHub Environment, requires manual reviewer approval before touching AWS
- Role ARNs are written into GitHub repo/environment variables automatically by `github-actions-oidc`'s own `apply`, no manual copy-pasting of ARNs anywhere in the pipeline