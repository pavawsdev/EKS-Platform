variable "namespace" {
  type    = string
  default = "argocd"
}

variable "argocd_chart_version" {
  type    = string
  default = "7.6.8"
}

variable "environment" {
  type = string
}

variable "repo_url" {
  description = "Git repository URL that ArgoCD will track (this repo)"
  type        = string
}

variable "target_revision" {
  description = "Git branch/tag ArgoCD tracks for this environment"
  type        = string
  default     = "main"
}

variable "domain_name" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
