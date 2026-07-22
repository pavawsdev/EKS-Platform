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
