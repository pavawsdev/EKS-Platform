provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

# These data sources create an implicit dependency: Kubernetes/Helm/kubectl
# providers only try to talk to the cluster once it exists.
data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_ca_data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_ca_data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

provider "kubectl" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_ca_data)
  token                  = data.aws_eks_cluster_auth.this.token
  load_config_file       = false
  apply_retry_count      = 5
}

# Address is a plain string built from an input variable (safe for a
# provider block - no dependency on a resource that doesn't exist yet).
# Auth token is read from the VAULT_TOKEN environment variable, never
# from a .tfvars file - see README "Vault bootstrap".
provider "vault" {
  address = "https://vault.${var.domain_name}"
}

# Reads back the master DB credential Terraform itself wrote into Vault
# (module.rds's own vault_kv_secret_v2.db_credentials) - lets the postgresql
# provider below authenticate without threading a sensitive master password
# through another module output. depends_on forces this read to wait for
# that write, which matters on the very first configure_vault=true apply
# where both happen in the same run - without it, Terraform could attempt
# the read before the secret exists.
data "vault_kv_secret_v2" "db_master" {
  count      = var.configure_vault ? 1 : 0
  mount      = module.vault.kv_mount_path
  name       = "${local.environment}/db"
  depends_on = [module.rds]
}

# Used to grant VulnTracker (and, later, any other app needing its own
# schema/role on the shared instance) isolated access without a dedicated
# RDS instance per app - see the vulntracker_db resources in main.tf.
# Credentials fall back to "unused" when configure_vault=false (first
# apply, before Vault itself is configured) since nothing actually uses
# this provider in that state - every resource that does is gated behind
# the same configure_vault flag.
provider "postgresql" {
  host            = module.rds.db_instance_address
  port            = 5432
  database        = module.rds.db_name
  username        = var.configure_vault ? data.vault_kv_secret_v2.db_master[0].data["username"] : "unused"
  password        = var.configure_vault ? data.vault_kv_secret_v2.db_master[0].data["password"] : "unused"
  sslmode         = "require"
  superuser       = false
  connect_timeout = 15
}
