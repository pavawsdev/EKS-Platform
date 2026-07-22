variable "name_prefix" {
  type = string
}

variable "domain_name" {
  description = "Placeholder base domain used to build the Cognito hosted UI domain prefix and callback URLs"
  type        = string
}

variable "callback_urls" {
  type    = list(string)
  default = []
}

variable "logout_urls" {
  type    = list(string)
  default = []
}

variable "environment" {
  type = string
}

variable "vault_kv_mount" {
  type    = string
  default = "secret"
}

variable "configure_vault" {
  type    = bool
  default = false
}

variable "tags" {
  type    = map(string)
  default = {}
}
