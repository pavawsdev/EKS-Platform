variable "name_prefix" {
  description = "Prefix used for naming all VPC resources"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "Availability zones to spread subnets across"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private (app/EKS) subnets"
  type        = list(string)
}

variable "database_subnet_cidrs" {
  description = "CIDR blocks for database (RDS) subnets"
  type        = list(string)
}

variable "single_nat_gateway" {
  description = "Use a single shared NAT gateway (cheaper, less HA) - typically true for dev/test, false for prod"
  type        = bool
  default     = true
}

variable "cluster_name" {
  description = "EKS cluster name, used for subnet auto-discovery tags"
  type        = string
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
