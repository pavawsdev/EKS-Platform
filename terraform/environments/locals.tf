locals {
  # terraform.workspace drives which environment we're in: dev / prod
  environment = terraform.workspace

  # Environment name and git branch name diverge for prod: the "prod"
  # environment is driven by the "main" branch, not a branch literally
  # named "prod" - everything else (workspace, tfvars, ECR/secret naming,
  # tags) uses the environment name, but ArgoCD's targetRevision needs the
  # actual branch it should sync from.
  git_branch = local.environment == "prod" ? "main" : local.environment

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
