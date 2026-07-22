terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.31"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.14"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.4"
    }
  }

  # NOTE: bucket/dynamodb table must be created once, out-of-band,
  # before first `terraform init` (see README "Bootstrap" section).
  # Workspaces (dev/test) are separated automatically via
  # workspace_key_prefix, so each gets its own state file:
  #   s3://<bucket>/env:/<workspace>/eks-platform/terraform.tfstate
  backend "s3" {
    bucket               = "REPLACE_WITH_YOUR_TF_STATE_BUCKET"
    key                  = "eks-platform/terraform.tfstate"
    region               = "ap-south-1"
    dynamodb_table       = "REPLACE_WITH_YOUR_TF_LOCK_TABLE"
    encrypt              = true
    workspace_key_prefix = "env"
  }
}
