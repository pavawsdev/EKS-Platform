variable "name_prefix" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "domain_name" {
  description = "Placeholder domain used for the ACM certificate and ingress host rules (e.g. app.example.com). Swap for a real domain later."
  type        = string
}

variable "create_acm_certificate" {
  description = "Whether to request an ACM cert for the ALB listener. Requires DNS validation against a real hosted zone, so keep false while using a placeholder domain."
  type        = bool
  default     = false
}

variable "enable_waf" {
  type    = bool
  default = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
