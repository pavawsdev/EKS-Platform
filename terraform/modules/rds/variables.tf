variable "name_prefix" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "db_subnet_group_name" {
  type = string
}

variable "eks_node_security_group_id" {
  description = "Security group of the EKS worker nodes, allowed to reach Postgres on 5432"
  type        = string
}

variable "vpc_cidr" {
  type = string
}

variable "engine_version" {
  type    = string
  default = "16.4"
}

variable "instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "allocated_storage" {
  type    = number
  default = 20
}

variable "max_allocated_storage" {
  type    = number
  default = 100
}

variable "multi_az" {
  type    = bool
  default = false
}

variable "backup_retention_period" {
  type    = number
  default = 7
}

variable "deletion_protection" {
  type    = bool
  default = false
}

variable "database_name" {
  type    = string
  default = "appdb"
}

variable "master_username" {
  type    = string
  default = "postgres"
}

variable "environment" {
  type = string
}

variable "vault_kv_mount" {
  description = "Vault KV v2 mount path where DB credentials are written"
  type        = string
  default     = "secret"
}

variable "configure_vault" {
  description = "Mirrors the vault module's flag - only write to Vault once it has been initialized and configured"
  type        = bool
  default     = false
}

variable "tags" {
  type    = map(string)
  default = {}
}
