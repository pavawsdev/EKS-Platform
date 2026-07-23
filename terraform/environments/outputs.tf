output "environment" {
  value = local.environment
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "configure_kubectl" {
  value = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "bastion_public_ip" {
  value = module.bastion.bastion_public_ip
}

output "argocd_server_url" {
  value = module.argocd.argocd_server_url
}

output "rds_endpoint" {
  value = module.rds.db_instance_endpoint
}

output "rds_vault_secret_path" {
  value = module.rds.vault_secret_path
}

output "vault_addr" {
  value = module.vault.vault_addr
}

output "vault_kms_key_arn" {
  value = module.vault.vault_kms_key_arn
}

output "cognito_user_pool_id" {
  value = module.cognito.user_pool_id
}

output "cognito_user_pool_client_id" {
  value = module.cognito.user_pool_client_id
}

output "waf_web_acl_arn" {
  value = module.alb.waf_web_acl_arn
}

output "github_token_secret_arn" {
  value     = var.github_token != "" ? aws_secretsmanager_secret.github_token[0].arn : "not created (github_token not supplied)"
  sensitive = true
}
