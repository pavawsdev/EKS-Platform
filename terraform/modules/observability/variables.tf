variable "name_prefix" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "cloudwatch_observability_role_arn" {
  description = "IRSA role ARN for the amazon-cloudwatch-observability EKS addon (Container Insights)"
  type        = string
}

variable "adot_collector_role_arn" {
  description = "IRSA role ARN for the ADOT collector's own service account (AMP remote-write + X-Ray write)"
  type        = string
}

variable "adot_collector_role_name" {
  description = "Name (not ARN) of the same role - needed to attach the AMP remote-write policy once the workspace ARN exists"
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
