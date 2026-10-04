# Terraform, Architecture Overview

This folder contains **five separate Terraform roots**, each with its own state file in S3. They are not one project split into subfolders, they are intentionally isolated because each has a different lifecycle and set of permissions.

```
terraform/
├── github-actions-oidc/     # CI/CD authentication layer (bootstrap)
├── infrastructure/          # VPC, EKS cluster, ECR, RDS, CloudWatch alarms
├── alb-controller-irsa/     # AWS Load Balancer Controller (IRSA + Helm)
├── external-secrets/        # External Secrets Operator (IRSA + Helm)
└── argocd/                  # ArgoCD (Helm) + the GitOps Application CR
```

## Why five separate states

If everything shared a single state, `terraform destroy` on the application infrastructure could also delete the IAM roles GitHub Actions uses to authenticate. Splitting these apart means:

- Destroying/rebuilding the cluster never touches CI's ability to authenticate
- A bad `apply` in one root can't corrupt state in another
- Each root can have its own scoped IAM permissions, following least privilege
- A dependent root (ALB controller, External Secrets, ArgoCD) simply can't produce a plan until the root it depends on has actually been applied.

## The five roots

### 1. `github-actions-oidc/`, authentication layer

Applied **manually, once, locally** using an IAM user, not through the pipeline, since this is what the pipeline itself depends on to exist first.

Manages:
- GitHub's OIDC provider (lets GitHub Actions authenticate to AWS without long-lived credentials)
- `terraform-plan-readonly`, read-only role, used by every `plan` job
- `terraform-apply`, privileged role, used only by `apply` jobs, trust gated to the `infra-apply` GitHub **Environment** 
- `github-actions-role-ecr-push`, scoped narrowly to ECR image push, used by the application's build/push workflow
- `github-actions-role-deploy-eks`, used only by the legacy direct-kubectl workflow, scoped to a namespace-level `AmazonEKSEditPolicy` access entry against `default`
- `github_actions_variable` resources (requires the `github` Terraform provider + a `GITHUB_TOKEN`) that publish all of the above role ARNs directly into GitHub repo/environment variables, not manually copy pasted.

State key: `github-actions-oidc/terraform.tfstate`

### 2. `infrastructure/`, the actual AWS infrastructure

Applied via the GitHub Actions pipeline: `plan` runs automatically on push to `main`, `apply` waits for manual approval via the `infra-apply` environment.

Manages:
- **VPC**, 2 AZs (EKS requirement), public + private subnets, single NAT Gateway (cost tradeoff), subnet tags required for EKS/ALB-controller discovery
- **EKS cluster**, node group on Spot `t3.small` instances (scaled to 2 nodes, see lessons below), public API endpoint, cluster's own OIDC provider (used by IRSA, separate from GitHub's OIDC provider), VPC CNI addon, EKS Access Entries (modern RBAC, replacing the legacy `aws-auth` ConfigMap) for `terraform-plan-readonly` (`AmazonEKSAdminViewPolicy`, cluster scope), `terraform-apply` (`AmazonEKSClusterAdminPolicy`, cluster scope), and `github-actions-role-deploy-eks` (`AmazonEKSEditPolicy`, namespace scope)
- **ECR**, single repository, immutable tags, scan-on-push, lifecycle policy expiring untagged images, `force_delete = true` (see tradeoffs)
- **RDS**, Postgres `db.t3.micro`/`gp2`, private subnets only, dedicated security group allowing only the EKS node security group on port 5432, master password fully managed by Secrets Manager (`manage_master_user_password = true`, Terraform never sees or stores the actual password)
- **CloudWatch Observability addon** (IRSA) + three alarms (RDS CPU, RDS free storage, pod restart count) wired to an SNS topic with an email subscription

State key: `infrastructure/terraform.tfstate`

### 3. `alb-controller-irsa/`, AWS Load Balancer Controller

Applied via the pipeline, **after** `infrastructure/`, since it depends on the live cluster (OIDC provider ARN, VPC ID, cluster endpoint) via `terraform_remote_state`, this root cannot plan meaningfully until the cluster already exists.

Manages:
- An IAM role trusted by the **cluster's** OIDC provider (IRSA), permissioned via AWS's official ALB controller policy (fetched dynamically via a `data "http"` source)
- The `aws-load-balancer-controller` Kubernetes ServiceAccount, annotated with the IAM role ARN
- The controller itself, installed via Helm

Once running, this controller watches for Kubernetes `Ingress` resources and automatically provisions real AWS ALBs to match. **Important:** that ALB, and the security groups it creates, are resources Terraform never created and has no record of.

State key: `alb-controller-irsa/terraform.tfstate`

### 4. `external-secrets/`, secrets sync

Also depends on the live cluster via `terraform_remote_state`.

Manages:
- An IRSA role scoped to `secretsmanager:GetSecretValue` / `DescribeSecret` on the RDS secret ARN, plus `kms:Decrypt`
- The External Secrets Operator, installed via Helm
- A `ClusterSecretStore` and an `ExternalSecret` (`kubernetes_manifest` resources) that sync the RDS username/password into a Kubernetes Secret (`rds-credentials`), with `target.template` composing a `DATABASE_URL` from `{{ .username }}` / `{{ .password }}` plus the known host/port/dbname

State key: `external-secrets/terraform.tfstate`

### 5. `argocd/`, GitOps controller

Also depends on the live cluster.

Manages:
- ArgoCD, installed via Helm (`server.service.type=ClusterIP`, `server.ingress.enabled=false`, `configs.params.server\.insecure=true` since it's only ever reached via `kubectl port-forward`, no second public ALB just for a dashboard; `dex`/`notifications`/`applicationSet` all disabled to trim pod count)
- The ArgoCD `Application` custom resource (a `kubernetes_manifest`) pointing `source.repoURL`/`path`/`targetRevision` at this repo's `k8s-manifests/`, with `destination.server = "https://kubernetes.default.svc"` (the special in-cluster value) and `destination.namespace = "default"`
- No `syncPolicy.automated` block, **sync is manual by design**, so every deployment is a deliberate, reviewed action rather than an automatic one

State key: `argocd/terraform.tfstate`

## Apply order

```
github-actions-oidc/     (manual, local, once, bootstraps everything else)
        │
        ▼
infrastructure/          (pipeline: plan → approval → apply)
        │
        ▼
alb-controller-irsa/     (pipeline: plan → approval → apply, depends on live cluster)
        │
        ▼
external-secrets/        (pipeline: plan → approval → apply, depends on live cluster)
        │
        ▼
argocd/                  (pipeline: plan → approval → apply, depends on live cluster)
```

The CI/CD pipeline enforces this order automatically: it detects which roots changed (`dorny/paths-filter`) and gates each root's `plan`/`apply` jobs on every earlier root having either succeeded or had nothing to apply.

## Authentication model

Two distinct OIDC trust relationships are in play, easy to get confused since they use the identical underlying AWS mechanism:

| | Identity format | Used by |
|---|---|---|
| **GitHub OIDC** | `repo:owner/repo:ref:...` / `repo:owner/repo:environment:...` | CI/CD pipeline authenticating to AWS |
| **EKS cluster OIDC (IRSA)** | `system:serviceaccount:<namespace>:<name>` | Pods inside the cluster (ALB controller, External Secrets, CloudWatch addon) authenticating to AWS |

Both use `sts:AssumeRoleWithWebIdentity` against an IAM OIDC provider, but they are two separate providers, trusting two separate token issuers, for two separate purposes.

## CI/CD pipeline summary (Terraform side)

- Trigger: push to `main`, path-filtered per root
- `plan` jobs use `terraform-plan-readonly`, read-only, runs automatically
- `apply` jobs use `terraform-apply`, gated behind the `infra-apply` GitHub Environment, requires manual reviewer approval before touching AWS
- `external-secrets-apply` and `argocd-apply` both require a **two-phase apply** on first install: `terraform apply -target=helm_release.X` first, then a full `terraform apply`. This is because Terraform validates `kubernetes_manifest` CRD schemas at *plan* time, before the CRDs installed by that same Helm release exist yet. Skipping straight to a full apply fails validation on a brand-new install.
- Role ARNs are written into GitHub repo/environment variables automatically by `github-actions-oidc`'s own `apply`, no manual copy-pasting of ARNs anywhere in the pipeline

## Teardown order

`terraform destroy` on `infrastructure/` **will fail** if you destroy the roots in the wrong order or skip a manual step, because of one specific gap: **the ALB itself, and its own security groups, are not Terraform resources.** They're created by the AWS Load Balancer Controller the moment it sees the `Ingress` object, Terraform's dependency graph has no idea they exist.

Correct teardown sequence:

```
1. kubectl delete ingress task-api-ingress --ignore-not-found=true   ← while the cluster is still alive
   (gives the controller a chance to deprovision the real ALB + its security groups itself)
2. terraform destroy  →  argocd/
3. terraform destroy  →  external-secrets/
4. terraform destroy  →  alb-controller-irsa/
5. terraform destroy  →  infrastructure/
```

Step 1 matters, **it has to happen before the ALB controller itself is destroyed, The controller is what actually reacts to the `Ingress` deletion and deprovisions the real ALB. Here's exactly what happens when you skip this:

1. `infrastructure` destroy fails on `DetachInternetGateway` and `DeleteSubnet` with `DependencyViolation`, the orphaned ALB's ENIs are still holding public IPs in the public subnets
2. Even after manually finding and deleting the ALB (`aws elbv2 describe-load-balancers` / `delete-load-balancer`), its two security groups (one for the ALB, one for node-to-ALB traffic) still block `aws ec2 delete-vpc`
3. Those have to be deleted by hand too (`aws ec2 describe-security-groups` / `delete-security-group`) before the VPC will finally delete

`.github/workflows/terraform-destroy.yml` runs `delete-ingress` as its **own dedicated first job**, before `destroy-argocd`, `destroy-external-secrets`, `destroy-alb-controller`, or `destroy-infrastructure`.

## Known tradeoffs

- **Single NAT Gateway**, not one per AZ, if its AZ has an outage, the node loses outbound internet access. Acceptable for a cluster that's destroyed/rebuilt between working sessions, a second NAT Gateway is the fix for HA.
- **Public EKS API endpoint**, a private endpoint is not applied yet.
- **2-node Spot node group**, originally sized at 1 node then raised to 2 after hitting real VPC CNI pod-IP exhaustion once ArgoCD's pod count landed on the node.
- **`AmazonEKSClusterAdminPolicy` granted to `terraform-apply`**, cluster wide. Broad. A tighter setup would scope this down to exactly the resource types Terraform actually manages via `kubernetes_manifest`.
- **Single-AZ RDS**, no Multi-AZ failover. Fine for a non-production learning workload, a real production DB would enable Multi-AZ.
- **`force_delete = true` on the ECR repository**, needed so `terraform destroy` doesn't fail on a non empty repo.
- **Shared `infra-apply` approval gate** across all four CI managed roots, one approval for all of them. A stricter setup would split this into separate environments per root.

## Lessons learned building this

1. **IRSA trust policy**: `Principal: Service` instead of `Federated`, so the CloudWatch addon's role existed but no pod could ever assume it.
2. **CNI pod-IP exhaustion**: one `t3.small` ran out of assignable pod IPs before CPU/memory; `ENABLE_PREFIX_DELEGATION` fixes it going forward, after node restart.
3. **`kubernetes_manifest` plan time CRD validation**: can't create a custom resource in the same apply that installs its CRD, needs a two phase `apply`.
4. **Helm chart URLs aren't uniform**: some publish via GitHub Pages, others as direct Release tarballs, check each one instead of assuming.
5. **RDS instance/storage class availability is specific to AZ**: a capacity error.
6. **Orphaned ALB + security groups blocking VPC teardown**: fully covered in "Teardown order."


## Local setup reference

A few one-time local steps are needed before any of this can be applied for the first time, mainly to bootstrap `github-actions-oidc/` itself, which by design can't be applied by CI.

```bash
# Configure AWS CLI with the IAM user's access key
aws configure

# Verify identity
aws sts get-caller-identity

# Manually create the S3 bucket for Terraform state
aws s3 mb s3://aws-eks-terraform-state-bucket

# Initialize a Terraform backend
terraform init

# Format all Terraform files recursively
terraform fmt --recursive
```

### IAM user permissions (`terraform-iam-user`)

This is the local IAM user used to apply `github-actions-oidc/`, `infrastructure/`, and `alb-controller-irsa/` by hand for verification. It's deliberately scoped tighter than "AdministratorAccess", AWS-managed policies cover the broad service actions, and inline policies fill in the specific gaps (OIDC provider management, scoped `PassRole`, the Terraform state bucket) that no single AWS-managed policy covers.

**AWS-managed policies attached:**

- `AmazonEC2ContainerRegistryFullAccess`
- `AmazonEC2FullAccess`
- `AmazonEKSClusterPolicy`
- `AmazonRDSFullAccess`
- `CloudWatchFullAccess`
- `SecretsManagerReadWrite`

**Inline policies** (full JSON in [`policies/`](./policies/)):

| File | Purpose |
|---|---|
| [`policies/eks-policy.json`](./policies/eks-policy.json) | Create/update/delete the EKS cluster, node groups, addons, and access entries |
| [`policies/iam-policy.json`](./policies/iam-policy.json) | Create/manage IAM roles, the OIDC provider, a scoped `PassRole` to exactly the three EKS related roles, and the two `CreateServiceLinkedRole` grants EKS needs on first use |
| [`policies/s3-policy.json`](./policies/s3-policy.json) | Read/write/create/delete access scoped to just the Terraform state bucket |
| [`policies/sts-policy.json`](./policies/sts-policy.json) | `sts:GetCallerIdentity` only, for the identity check above |

Note the `iam-policy.json` `PassEKSRoles` statement is scoped to three specific role ARNs with a `iam:PassedToService` condition, this is what keeps the IAM policy from being a blanket `iam:PassRole` on `*`, which would let this user hand off any role to any service.

### GitHub fine-grained PAT

Needed by the `github-actions-oidc` Terraform root's `github_actions_variable` resources (they write role ARNs into GitHub repo/environment variables via the `github` provider) and by the Terraform pipeline's `TF_GITHUB_PAT` secret.

Create a **fine-grained personal access token** with:

- **Repository access:** only select repositories → this repo
- **Repository permissions:**
  - Actions: Read and write
  - Environments: Read and write
  - Variables: Read and write
  - Metadata: Read-only (required automatically)

```bash
export GITHUB_TOKEN="github_pat_..."
```

### Cluster health checks

```bash
# Confirm AWS CLI is authenticated
aws sts get-caller-identity

# Point kubectl at the cluster
aws eks update-kubeconfig --region us-east-1 --name aws-eks-terraform

# Nodes ready?
kubectl get nodes

# All pods, all namespaces
kubectl get pods -A

# EKS cluster details
aws eks describe-cluster --region us-east-1 --name aws-eks-terraform
```

**AWS Load Balancer Controller specifically:**

```bash
kubectl get pods -n kube-system
kubectl get deployment -n kube-system aws-load-balancer-controller
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# IRSA annotation actually present on the ServiceAccount?
kubectl get serviceaccount aws-load-balancer-controller -n kube-system -o yaml

# Controller logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller
```

### External Secrets Operator notes

`terraform/external-secrets/main.tf`, `helm_release.aws_eso`:

- `atomic = true`, if the Helm install fails, Helm rolls it back automatically instead of leaving a partial release behind
- `wait = true`, Terraform waits for the Kubernetes resources to actually become ready before calling the release successful
- `timeout = 600`, 10 minutes, rather than timing out too early

Because the `ClusterSecretStore`/`ExternalSecret` custom resources depend on CRDs this same Helm release installs, the first apply needs the two-phase pattern described above:

```bash
terraform apply -target=helm_release.aws_eso -auto-approve
```

### ArgoCD setup

```bash
# Check the current chart version before pinning one
helm repo add argo https://argoproj.github.io/argo-helm
helm search repo argo/argo-cd
# → argo/argo-cd   10.9.2   v3.5.3   A Helm chart for Argo CD, a declarative, GitOps...

# Download the chart locally (this repo vendors the .tgz rather than fetching it at apply time)
mkdir -p terraform/argocd/charts
curl -L https://argoproj.github.io/argo-helm/argo-cd-10.9.2.tgz \
  -o terraform/argocd/charts/argo-cd.tgz

# First apply needs the same two-phase pattern as External Secrets
terraform apply -target=helm_release.argocd -auto-approve
```

**Reaching the UI**:

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:80
```

**Getting the initial admin password** (in a second terminal, while the port-forward above stays running):

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
# or, on some shells:
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 --decode
```

### Bootstrapping `external-secrets`/`argocd` on a completely fresh cluster

`external-secrets` and `argocd` both define `kubernetes_manifest` resources (`ClusterSecretStore`/`ExternalSecret`, the ArgoCD `Application`) whose CRDs are installed by their *own* Helm release in the same root. On a cluster with zero history, even `terraform plan` fails validating those resources, the CRD schema it needs to check against doesn't exist yet. Fastest way through it is bootstrapping locally once, then letting CI take over normally from there:

```bash
# 1. Grant your local IAM identity temporary cluster access 
aws sts get-caller-identity   # note the Arn
aws eks create-access-entry --cluster-name aws-eks-terraform --principal-arn <your-local-arn> --type STANDARD --region us-east-1
aws eks associate-access-policy --cluster-name aws-eks-terraform --principal-arn <your-local-arn> \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy --access-scope type=cluster --region us-east-1

# 2. Point kubectl/the Terraform kubernetes provider at the cluster
aws eks update-kubeconfig --region us-east-1 --name aws-eks-terraform

# 3. Two-phase apply, both roots (installs the CRDs, then the custom resources that depend on them)
cd terraform/external-secrets && terraform init \
  && terraform apply -target=helm_release.aws_eso -auto-approve && terraform apply -auto-approve

cd ../argocd && terraform init \
  && terraform apply -target=helm_release.argocd -auto-approve && terraform apply -auto-approve

# 4. Revoke the temporary grant, it's unmanaged by Terraform and stays overly broad if left in place
aws eks delete-access-entry --cluster-name aws-eks-terraform --principal-arn <your-local-arn>
```

After this, re-run the CI Terraform pipeline, `external-secrets-plan`/`argocd-plan` now succeed normally, since the CRDs they validate against already exist. This is a one-time step per fresh cluster build, not something needed on every push, avoid running it at the same time CI is applying the same roots, since both share the same S3 state with native locking.
