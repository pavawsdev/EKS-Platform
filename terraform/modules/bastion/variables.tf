variable "name_prefix" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_id" {
  description = "Bastion lives in a private subnet - it's reached via SSM Session Manager (outbound-only through the NAT gateway), never needs a public IP or inbound internet access"
  type        = string
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed to SSH into the bastion. Restrict to your office/VPN CIDR in real use."
  type        = list(string)
  default     = []
}

variable "key_name" {
  description = "Existing EC2 key pair name for SSH access. Leave empty to rely on SSM Session Manager only."
  type        = string
  default     = ""
}

variable "cluster_name" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
