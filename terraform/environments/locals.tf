locals {
  # terraform.workspace drives which environment we're in: dev / stage / prod
  environment = terraform.workspace

  # Only two branches exist, "dev" and "main" - there's no branch literally
  # named "stage" or "prod". The "dev" environment is driven by the "dev"
  # branch; "stage" and "prod" are both driven by "main", distinguished only
  # by which values file each environment's ArgoCD Applications point at
  # (see gitops/environments/<env>/ and ci.yml's promote-* jobs) - this is
  # the deliberate "only two branches, no branch-sync drift" choice, not an
  # oversight. Everywhere else (workspace, tfvars, ECR/secret naming, tags)
  # uses the environment name, but ArgoCD's targetRevision needs the actual
  # branch it should sync from.
  git_branch = local.environment == "dev" ? "dev" : "main"

  name_prefix  = "${var.project_name}-${local.environment}"
  cluster_name = "${local.name_prefix}-eks"

  # Every resource across every module gets these tags merged in,
  # in addition to each module's own resource-specific tags.
  common_tags = {
    Project     = var.project_name
    Environment = local.environment
    ManagedBy   = "terraform"
    Workspace   = terraform.workspace
    CostCenter  = var.cost_center
    Owner       = var.owner
  }

  env_config = var.environment_config[local.environment]
}
