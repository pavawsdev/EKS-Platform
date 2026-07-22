output "db_instance_endpoint" {
  value = aws_db_instance.postgres.endpoint
}

output "db_instance_address" {
  value = aws_db_instance.postgres.address
}

output "db_name" {
  value = aws_db_instance.postgres.db_name
}

output "vault_secret_path" {
  value = "${var.vault_kv_mount}/data/${var.environment}/db"
}

output "rds_security_group_id" {
  value = aws_security_group.rds.id
}
