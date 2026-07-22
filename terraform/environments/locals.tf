locals {
  # terraform.workspace drives which environment we're in: dev / test
  environment = terraform.workspace

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
