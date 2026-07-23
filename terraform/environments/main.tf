data "aws_caller_identity" "current" {}

############################################
# VPC
############################################
module "vpc" {
  source = "../modules/vpc"

  name_prefix           = local.name_prefix
  cluster_name          = local.cluster_name
  vpc_cidr              = local.env_config.vpc_cidr
  azs                   = local.env_config.azs
  public_subnet_cidrs   = local.env_config.public_subnet_cidrs
  private_subnet_cidrs  = local.env_config.private_subnet_cidrs
  database_subnet_cidrs = local.env_config.database_subnet_cidrs
  single_nat_gateway    = local.env_config.single_nat_gateway
  tags                  = local.common_tags
}

############################################
# EKS Cluster + Managed Node Groups
############################################
module "eks" {
  source = "../modules/eks"

  name_prefix                  = local.name_prefix
  cluster_name                 = local.cluster_name
  cluster_version              = var.eks_cluster_version
  vpc_id                       = module.vpc.vpc_id
  vpc_cidr                     = module.vpc.vpc_cidr
  private_subnet_ids           = module.vpc.private_subnet_ids
  public_subnet_ids            = module.vpc.public_subnet_ids
  endpoint_public_access       = local.env_config.endpoint_public_access
  endpoint_public_access_cidrs = var.allowed_ssh_cidrs

  node_groups = {
    default = {
      instance_types = local.env_config.node_instance_types
      capacity_type  = local.env_config.node_capacity_type
      disk_size      = local.env_config.node_disk_size
      min_size       = local.env_config.node_min_size
      max_size       = local.env_config.node_max_size
      desired_size   = local.env_config.node_desired_size
      labels         = { workload = "general", environment = local.environment }
      taints         = []
    }
  }

  tags = local.common_tags
}

############################################
# OIDC / IRSA roles for cluster add-ons
############################################
module "oidc" {
  source = "../modules/oidc"

  name_prefix       = local.name_prefix
  cluster_name      = local.cluster_name
  oidc_provider_url = module.eks.oidc_provider_url
  oidc_provider_arn = module.eks.oidc_provider_arn
  tags              = local.common_tags
}

############################################
# ALB security group, WAF, optional ACM cert
############################################
module "alb" {
  source = "../modules/alb"

  name_prefix            = local.name_prefix
  vpc_id                 = module.vpc.vpc_id
  vpc_cidr               = module.vpc.vpc_cidr
  domain_name            = var.domain_name
  create_acm_certificate = local.env_config.create_acm_cert
  enable_waf             = local.env_config.enable_waf
  tags                   = local.common_tags
}

############################################
# Cluster add-ons (Helm): ALB controller,
# cluster-autoscaler, metrics-server, external-dns
############################################
module "add_ons" {
  source = "../modules/add-ons"

  cluster_name                = module.eks.cluster_name
  vpc_id                      = module.vpc.vpc_id
  aws_region                  = var.aws_region
  lb_controller_role_arn      = module.oidc.lb_controller_role_arn
  cluster_autoscaler_role_arn = module.oidc.cluster_autoscaler_role_arn
  external_dns_role_arn       = module.oidc.external_dns_role_arn
  enable_external_dns         = local.env_config.enable_external_dns
  hosted_zone_id              = local.env_config.hosted_zone_id
  tags                        = local.common_tags

  depends_on = [module.eks]
}

############################################
# ArgoCD (GitOps controller) + app-of-apps bootstrap
############################################
module "argocd" {
  source = "../modules/argocd"

  environment     = local.environment
  repo_url        = var.repo_url
  target_revision = local.environment # "dev" or "test" branch, 1:1 with the workspace
  domain_name     = var.domain_name
  tags            = local.common_tags

  depends_on = [module.add_ons]
}

############################################
# HashiCorp Vault - stores DB credentials, the
# Cognito client secret, and any application/API
# tokens. Deployed here; KV mount + Kubernetes
# auth + policies only get configured once
# var.configure_vault = true (see README).
############################################
module "vault" {
  source = "../modules/vault"

  name_prefix                   = local.name_prefix
  environment                   = local.environment
  cluster_name                  = module.eks.cluster_name
  oidc_provider_arn             = module.eks.oidc_provider_arn
  oidc_provider_url             = module.eks.oidc_provider_url
  domain_name                   = var.domain_name
  configure_vault               = var.configure_vault
  kubernetes_host               = module.eks.cluster_endpoint
  kubernetes_ca_cert            = base64decode(module.eks.cluster_ca_data)
  backend_service_account_name  = "backend"
  frontend_service_account_name = "frontend"
  tags                          = local.common_tags

  depends_on = [module.add_ons]
}

############################################
# GitHub PAT used by CI for GitOps commits -
# stored in AWS Secrets Manager (per the request
# to keep GitHub tokens there rather than in Vault).
# Value is only written if var.github_token is
# supplied via TF_VAR_github_token in CI; never
# committed to a tfvars file.
############################################
resource "aws_kms_key" "github_token" {
  count                   = var.github_token != "" ? 1 : 0
  description             = "KMS key for ${local.name_prefix} GitHub token secret"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  tags                    = local.common_tags

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnableIAMUserPermissions"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      }
    ]
  })
}

# Automatic rotation (CKV2_AWS_57) is deliberately not implemented: this
# secret is a manually-issued GitHub PAT, and GitHub has no API to rotate
# a PAT's value in place - a "rotation" Lambda here could only generate a
# new AWS-side random string, not a working GitHub credential, so it would
# add cost and complexity without adding real security. The correct fix is
# migrating CI's GitOps auth to a GitHub App installation token (auto-expires
# hourly, fetched fresh every run) instead of a long-lived PAT - a bigger
# change than this hardening pass, tracked as a follow-up.
#checkov:skip=CKV2_AWS_57:no GitHub API exists to rotate a PAT in place; real fix is switching to GitHub App installation tokens (see comment above)
resource "aws_secretsmanager_secret" "github_token" {
  count                   = var.github_token != "" ? 1 : 0
  name                    = "${local.name_prefix}-github-token"
  recovery_window_in_days = 7
  kms_key_id              = aws_kms_key.github_token[0].id
  tags                    = local.common_tags
}

resource "aws_secretsmanager_secret_version" "github_token" {
  count         = var.github_token != "" ? 1 : 0
  secret_id     = aws_secretsmanager_secret.github_token[0].id
  secret_string = var.github_token
}

############################################
# Arbitrary application / third-party API tokens
# -> Vault (never AWS Secrets Manager, never tfvars)
############################################
resource "vault_kv_secret_v2" "api_tokens" {
  count = var.configure_vault && length(var.app_api_tokens) > 0 ? 1 : 0

  mount     = module.vault.kv_mount_path
  name      = "${local.environment}/api-tokens"
  data_json = jsonencode(var.app_api_tokens)

  depends_on = [module.vault]
}

############################################
# Bastion host (jump box into the private VPC)
############################################
module "bastion" {
  source = "../modules/bastion"

  name_prefix       = local.name_prefix
  vpc_id            = module.vpc.vpc_id
  private_subnet_id = module.vpc.private_subnet_ids[0]
  allowed_ssh_cidrs = var.allowed_ssh_cidrs
  key_name          = var.ec2_key_name
  cluster_name      = local.cluster_name
  tags              = local.common_tags
}

############################################
# Cognito (auth for the frontend / ALB listener rules)
############################################
module "cognito" {
  source = "../modules/cognito"

  name_prefix     = local.name_prefix
  domain_name     = var.domain_name
  environment     = local.environment
  vault_kv_mount  = module.vault.kv_mount_path
  configure_vault = var.configure_vault
  tags            = local.common_tags

  depends_on = [module.vault]
}

############################################
# RDS Postgres
############################################
module "rds" {
  source = "../modules/rds"

  name_prefix                = local.name_prefix
  vpc_id                     = module.vpc.vpc_id
  vpc_cidr                   = module.vpc.vpc_cidr
  db_subnet_group_name       = module.vpc.db_subnet_group_name
  eks_node_security_group_id = module.eks.cluster_security_group_id
  instance_class             = local.env_config.rds_instance_class
  allocated_storage          = local.env_config.rds_allocated_storage
  max_allocated_storage      = local.env_config.rds_max_allocated_storage
  multi_az                   = local.env_config.rds_multi_az
  deletion_protection        = local.env_config.rds_deletion_protection
  backup_retention_period    = local.env_config.rds_backup_retention_period
  environment                = local.environment
  vault_kv_mount             = module.vault.kv_mount_path
  configure_vault            = var.configure_vault
  tags                       = local.common_tags

  depends_on = [module.vault]
}
