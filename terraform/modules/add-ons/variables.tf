variable "cluster_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "lb_controller_role_arn" {
  type = string
}

variable "cluster_autoscaler_role_arn" {
  type = string
}

variable "external_dns_role_arn" {
  type = string
}

variable "enable_external_dns" {
  type    = bool
  default = false
}

variable "hosted_zone_id" {
  type    = string
  default = ""
}

variable "tags" {
  type    = map(string)
  default = {}
}
