variable "project_name" {
  description = "Short project name, used as a prefix for all resources"
  type        = string
  default     = "eksplat"
}

variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "owner" {
  type    = string
  default = "platform-team"
}

variable "cost_center" {
  type    = string
  default = "engineering"
}

variable "domain_name" {
  description = "Placeholder domain (swap for a real Route53-hosted domain later)"
  type        = string
  default     = "example.internal"
}

variable "repo_url" {
  description = "Git URL of this repository, used by ArgoCD to locate manifests"
  type        = string
  default     = "https://github.com/pavawsdev/EKS-Platform.git"
}

variable "eks_cluster_version" {
  type    = string
  default = "1.30"
}

variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed to reach the bastion on port 22"
  type        = list(string)
  default     = []
}

variable "ec2_key_name" {
  description = "Existing EC2 key pair for bastion SSH (optional - SSM Session Manager works without it)"
  type        = string
  default     = ""
}

# Per-workspace (dev/test) sizing and topology, keyed by
# terraform.workspace name. Populated from tfvars/<env>.tfvars.
variable "environment_config" {
  description = "Per-environment (dev/test) configuration, keyed by workspace name"
  type = map(object({
    vpc_cidr               = string
    azs                     = list(string)
    public_subnet_cidrs    = list(string)
    private_subnet_cidrs   = list(string)
    database_subnet_cidrs  = list(string)
    single_nat_gateway     = bool
    endpoint_public_access = bool

    node_instance_types = list(string)
    node_capacity_type  = string
    node_disk_size      = number
    node_min_size       = number
    node_max_size       = number
    node_desired_size   = number

    rds_instance_class          = string
    rds_allocated_storage       = number
    rds_max_allocated_storage   = number
    rds_multi_az                = bool
    rds_deletion_protection     = bool
    rds_backup_retention_period = number

    enable_external_dns = bool
    hosted_zone_id      = string
    create_acm_cert     = bool
    enable_waf          = bool
  }))
}

############################################
# Secrets management
############################################

variable "configure_vault" {
  description = "False on the first apply (Vault is only just being deployed). Set to true (via -var or TF_VAR_configure_vault) once Vault has been initialized and unsealed - see README 'Vault bootstrap'."
  type        = bool
  default     = false
}

variable "kubernetes_ca_cert" {
  description = "Populated automatically from the EKS module output - passed through to Vault's Kubernetes auth backend config"
  type        = string
  default     = ""
}

variable "github_token" {
  description = "GitHub PAT used by CI to push GitOps commits (helm values bumps). Stored in AWS Secrets Manager, never committed - set via TF_VAR_github_token in the CI environment, not in a tfvars file. Leave empty to skip creating the secret."
  type        = string
  default     = ""
  sensitive   = true
}

variable "app_api_tokens" {
  description = "Arbitrary third-party API tokens the application needs (payment provider, email provider, etc). Written to Vault, never to AWS Secrets Manager or tfvars - set via TF_VAR_app_api_tokens in the CI/local environment."
  type        = map(string)
  default     = {}
  sensitive   = true
}
