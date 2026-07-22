project_name = "eksplat"
aws_region   = "ap-south-1"
owner        = "platform-team"
cost_center  = "engineering"
domain_name  = "test.example.internal"
repo_url     = "https://github.com/pavawsdev/EKS-Platform.git"

allowed_ssh_cidrs = ["203.0.113.0/24"] # replace with your office/VPN CIDR

environment_config = {
  test = {
    vpc_cidr              = "10.20.0.0/16"
    azs                   = ["ap-south-1a", "ap-south-1b"]
    public_subnet_cidrs   = ["10.20.0.0/24", "10.20.1.0/24"]
    private_subnet_cidrs  = ["10.20.10.0/24", "10.20.11.0/24"]
    database_subnet_cidrs = ["10.20.20.0/24", "10.20.21.0/24"]
    single_nat_gateway    = true
    endpoint_public_access = true

    node_instance_types = ["t3.medium"]
    node_capacity_type  = "SPOT"
    node_disk_size      = 30
    node_min_size       = 1
    node_max_size        = 4
    node_desired_size     = 2

    rds_instance_class          = "db.t4g.small"
    rds_allocated_storage       = 20
    rds_max_allocated_storage   = 100
    rds_multi_az                = false
    rds_deletion_protection     = false
    rds_backup_retention_period = 5

    enable_external_dns = false
    hosted_zone_id       = ""
    create_acm_cert      = false
    enable_waf           = true
  }
}
