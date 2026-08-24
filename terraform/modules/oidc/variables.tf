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

variable "environment" {
  description = "dev / prod - used to build the backend/worker namespace strings"
  type        = string
}

variable "sqs_jobs_queue_arn" {
  description = "ARN of the jobs SQS queue, for the backend/worker/keda_operator IRSA policies"
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
