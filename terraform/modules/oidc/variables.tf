variable "name_prefix" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "oidc_provider_url" {
  description = "EKS cluster OIDC issuer URL (without https://)"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the EKS OIDC provider (created in the eks module)"
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
