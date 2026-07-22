variable "name_prefix" {
  type = string
}

variable "environment" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "oidc_provider_arn" {
  type = string
}

variable "oidc_provider_url" {
  type = string
}

variable "domain_name" {
  type = string
}

variable "vault_helm_version" {
  type    = string
  default = "0.28.1"
}

variable "vault_namespace" {
  type    = string
  default = "vault"
}

variable "configure_vault" {
  description = "Set true only after Vault has been initialized and unsealed (see README Vault bootstrap). False on the first apply so the KV mount / auth backend / policies aren't attempted against an uninitialized Vault."
  type        = bool
  default     = false
}

variable "kubernetes_host" {
  description = "EKS cluster API endpoint, used by Vault's Kubernetes auth backend to validate service account tokens"
  type        = string
  default     = ""
}

variable "kubernetes_ca_cert" {
  description = "EKS cluster CA certificate (PEM), used by Vault's Kubernetes auth backend"
  type        = string
  default     = ""
}

variable "backend_service_account_name" {
  type    = string
  default = "backend"
}

variable "frontend_service_account_name" {
  type    = string
  default = "frontend"
}

variable "tags" {
  type    = map(string)
  default = {}
}
