# EKS Platform Demo

A production-style reference implementation for deploying a frontend + backend
application onto AWS EKS using:

- **Terraform** (module-based, one workspace per environment: `dev` / `test`)
- **GitHub Actions** for CI/CD, with security scanning gating every deploy
- **ArgoCD** for GitOps-based delivery
- **Helm** for packaging the frontend and backend
- **HashiCorp Vault** for application, database, and API-token secrets
- **AWS Secrets Manager** for the one credential Vault doesn't hold: the
  GitHub token CI uses to push GitOps commits

## Repository layout

```
terraform/
  modules/            # vpc, oidc, eks, add-ons, alb, argocd, bastion, cognito, rds, vault
  environments/        # root config that wires modules together, one per workspace
    tfvars/             # dev.tfvars, test.tfvars
apps/
  frontend/            # sample React app
  backend/             # sample Node/Express API
helm/
  frontend/            # Helm chart + values-{dev,test}.yaml
  backend/             # same, plus Vault Agent Injector annotations
argocd/
  applications/        # one Application manifest per service per environment
  projects/            # AppProject (RBAC boundary)
.github/workflows/
  terraform.yml         # plan/apply/destroy per workspace, OIDC auth to AWS
  security-scan.yml     # gitleaks, tfsec, checkov, CodeQL, Trivy, kube-linter
  frontend-ci.yml        # test -> build -> image scan gate -> push -> GitOps commit
  backend-ci.yml
```

## How it fits together

1. A developer pushes code to `dev` or `test`.
2. GitHub Actions runs tests, then the **security gate** (SAST, secret scanning,
   dependency/image scanning) — a failed scan blocks the image from ever
   reaching ECR.
3. On success, the image is pushed to ECR. A follow-up job fetches a GitHub
   push token from **AWS Secrets Manager** (via the same OIDC-federated AWS
   role, no static AWS keys) and uses it to commit the new image tag into
   `helm/<service>/values-<env>.yaml`.
4. ArgoCD (installed by the `argocd` Terraform module, bootstrapped as an
   "app-of-apps" watching `argocd/applications/`) detects the Git change and
   syncs the corresponding Helm release into the cluster automatically.
5. At runtime, each pod's Vault Agent Injector sidecar fetches DB credentials
   straight from Vault and writes them to an in-memory file the app sources
   at startup — nothing secret ever sits in a Helm value, ConfigMap, or plain
   Kubernetes Secret.
6. The Terraform pipeline is entirely separate: infrastructure changes go
   through `terraform plan` (commented on the PR) and a manual-approval
   `apply`/`destroy` via `workflow_dispatch`, scoped per environment using
   **Terraform workspaces**.

## Secrets model

| Secret | Stored in | Who reads it |
|---|---|---|
| DB (RDS Postgres) credentials | Vault KV v2, `secret/<env>/db` | Backend pod, via Vault Agent Injector sidecar |
| Cognito app client secret | Vault KV v2, `secret/<env>/cognito` | Any service that needs to complete the OAuth flow server-side |
| Third-party API tokens | Vault KV v2, `secret/<env>/api-tokens` | Backend pod, same injector pattern |
| GitHub PAT for GitOps commits | AWS Secrets Manager, `eksplat-<env>-github-token` | GitHub Actions (`update-manifest` job), via OIDC-assumed AWS role |

Nothing above is ever written to a `.tfvars` file. `github_token` and
`app_api_tokens` are Terraform variables with `sensitive = true` and empty
defaults — supply them at apply time via `TF_VAR_github_token` /
`TF_VAR_app_api_tokens` environment variables (the GitHub Actions workflows
already do this from `secrets.GITOPS_GITHUB_PAT`).

Pods authenticate to Vault using their own Kubernetes service account token
(Vault's Kubernetes auth method validates it directly against the cluster's
TokenReview API) — no Vault token is ever stored in a Secret, an env var, or
an image.

## Vault bootstrap (one-time per environment)

Terraform can deploy Vault, but it cannot initialize or unseal it for
you — that's a deliberate Vault design choice (someone has to hold the
initial recovery keys). The flow:

```bash
cd terraform/environments
terraform workspace select dev   # or test

# Phase 1: deploy Vault only (KV mount / auth backend / policies are
# gated behind configure_vault so they aren't attempted yet)
terraform apply -target=module.vault -var-file=tfvars/dev.tfvars

# One-time initialization (auto-unseal via AWS KMS means you never run
# `vault operator unseal` - not here, not after a restart, ever again)
kubectl -n vault exec -it vault-0 -- vault operator init
# -> save the recovery keys + initial root token somewhere safe (a
#    password manager, not this repo)

export VAULT_TOKEN=<initial root token, or a scoped bootstrap token>

# Phase 2: configure the KV mount, Kubernetes auth backend, policies,
# and write the DB / Cognito secrets Vault now has everywhere it needs to
terraform apply -var-file=tfvars/dev.tfvars -var="configure_vault=true"
```

In CI, `VAULT_TOKEN` is stored as a GitHub Actions secret and
`TF_VAR_configure_vault` is driven by the `CONFIGURE_VAULT` repository/
environment variable (defaults to `false` so a fresh environment's first
pipeline run doesn't fail trying to configure an uninitialized Vault).

## Bootstrap (one-time, before first `terraform init`)

Terraform state needs somewhere to live before any workspace can be created:

```bash
aws s3api create-bucket --bucket <your-tf-state-bucket> --region ap-south-1 \
  --create-bucket-configuration LocationConstraint=ap-south-1
aws s3api put-bucket-versioning --bucket <your-tf-state-bucket> \
  --versioning-configuration Status=Enabled
aws dynamodb create-table --table-name <your-tf-lock-table> \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

Then update the bucket/table names in `terraform/environments/versions.tf`.

Also create, in GitHub:
- An OIDC-federated IAM role (`AWS_DEPLOY_ROLE_ARN` secret) trusted by
  `token.actions.githubusercontent.com` — no long-lived AWS keys are stored
  in GitHub. It needs `secretsmanager:GetSecretValue` on the GitHub-token
  secret in addition to the usual Terraform/EKS/ECR permissions.
- A `VAULT_TOKEN` secret (see "Vault bootstrap" above).
- A `GITOPS_GITHUB_PAT` secret — a GitHub PAT with `repo` scope, used as
  the *value* written into the `eksplat-<env>-github-token` AWS Secrets
  Manager entry (so Terraform can create the secret container and CI can
  populate + later read it).
- GitHub Environments named `dev` and `test` (and `<env>-plan`,
  `<env>-destroy`) so you can attach required-reviewer approval rules if
  you want manual gates on apply.

## Using Terraform workspaces

```bash
cd terraform/environments
terraform init

terraform workspace new dev    # first time only
terraform workspace select dev
terraform plan  -var-file=tfvars/dev.tfvars
terraform apply -var-file=tfvars/dev.tfvars

# same pattern for test:
terraform workspace new test
terraform workspace select test
terraform apply -var-file=tfvars/test.tfvars
```

Every resource is tagged with `Environment = terraform.workspace` plus
`Project`, `ManagedBy`, `Workspace`, `CostCenter`, and `Owner` (see
`terraform/environments/locals.tf`), so cost and ownership are traceable
per workspace in the AWS console/Cost Explorer.

`environment_config` in `variables.tf` is keyed by workspace name and
drives the real differences between environments:

| | dev | test |
|---|---|---|
| NAT gateways | 1 shared | 1 shared |
| EKS endpoint | public | public |
| Node capacity | SPOT | SPOT |
| RDS Multi-AZ | no | no |
| RDS deletion protection | no | no |
| WAF | enabled | enabled |

Both environments are intentionally similar here since there's no `prod` —
tighten `test` further (Multi-AZ, deletion protection, dedicated NAT per AZ,
private-only EKS endpoint) if you want it to double as a pre-production
gate before adding a third workspace later.

## Connecting to the cluster

```bash
aws eks update-kubeconfig --region ap-south-1 --name eksplat-<env>-eks
kubectl get nodes
```

Or via the bastion (SSM Session Manager, no open SSH port needed):

```bash
aws ssm start-session --target <bastion-instance-id>
```

## Placeholders you must replace before this is production-ready

- `terraform/environments/versions.tf` — S3 bucket / DynamoDB table names
- `terraform/environments/tfvars/*.tfvars` — `domain_name`, `allowed_ssh_cidrs`
- `argocd/applications/*.yaml` and the `argocd` module's `repo_url` variable —
  point at your actual Git remote
- `helm/*/values.yaml` — `image.repository` (your ECR registry URL)
- `helm/backend/values-*.yaml` — `vault.addr` (must match `vault.<domain_name>`
  for that environment)
- GitHub secrets — `AWS_DEPLOY_ROLE_ARN`, `VAULT_TOKEN`, `GITOPS_GITHUB_PAT`

## Security notes

- No AWS access keys anywhere — GitHub Actions authenticates via OIDC, pods
  authenticate to AWS via IRSA and to Vault via their Kubernetes service
  account token (see `terraform/modules/oidc` and `terraform/modules/vault`).
- Vault auto-unseals via AWS KMS (IRSA-scoped to that one key) — the only
  manual step, ever, is the initial `vault operator init`.
- RDS only accepts connections from the EKS node security group; the
  master password is generated by Terraform and written straight to Vault,
  never to AWS Secrets Manager and never to a plain Kubernetes Secret.
- The GitHub token used for GitOps commits lives in AWS Secrets Manager,
  fetched at CI time via the OIDC-assumed role — not stored as a static
  GitHub Actions secret used directly for git auth.
- The bastion uses IMDSv2, SSM Session Manager, and has no inbound rule at
  all unless you set `allowed_ssh_cidrs`.
- WAFv2 (common rule set + known-bad-inputs + rate limiting) sits in front
  of the ALB by default in every environment.
- Every CI pipeline run is gated by SAST, secret scanning, dependency
  scanning, and container image scanning before anything reaches ECR.
