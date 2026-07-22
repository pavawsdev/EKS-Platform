output "vault_addr" {
  value = "https://vault.${var.domain_name}"
}

output "vault_namespace" {
  value = kubernetes_namespace.vault.metadata[0].name
}

output "vault_kms_key_arn" {
  value = aws_kms_key.vault_unseal.arn
}

output "kv_mount_path" {
  value = var.configure_vault ? vault_mount.kv[0].path : "secret"
}
