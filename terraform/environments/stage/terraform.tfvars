project_name = "eksplat"
aws_region   = "ap-south-1"
owner        = "platform-team"
cost_center  = "engineering"
domain_name  = "stage.example.internal"
repo_url     = "https://github.com/pavawsdev/EKS-Platform.git"

allowed_ssh_cidrs = ["203.0.113.0/24"] # replace with your office/VPN CIDR

environment_config = {
  stage = {
    vpc_cidr               = "10.15.0.0/16" # distinct /16 from dev (10.10) and prod (10.20)
    azs                    = ["ap-south-1a", "ap-south-1b"]
    public_subnet_cidrs    = ["10.15.0.0/24", "10.15.1.0/24"]
    private_subnet_cidrs   = ["10.15.10.0/24", "10.15.11.0/24"]
    database_subnet_cidrs  = ["10.15.20.0/24", "10.15.21.0/24"]
    single_nat_gateway     = true
    endpoint_public_access = true

    node_instance_types = ["t3.medium"]
    node_capacity_type  = "SPOT"
    node_disk_size      = 30
    node_min_size       = 1
    node_max_size       = 3
    node_desired_size   = 2

    rds_instance_class          = "db.t4g.small"
    rds_allocated_storage       = 20
    rds_max_allocated_storage   = 75
    rds_multi_az                = false
    rds_deletion_protection     = false
    rds_backup_retention_period = 4

    enable_external_dns  = false
    hosted_zone_id       = ""
    create_acm_cert      = false
    enable_waf           = true  # mirrors prod's ingress posture - stage exists to validate the real path before prod
    enable_observability = false # AMP + Managed Grafana + Container Insights + X-Ray all bill on usage - see README "Observability"; not applied yet
  }
}
