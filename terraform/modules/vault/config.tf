############################################
# Everything below talks to the Vault API itself
# (via the `vault` provider, configured in
# terraform/environments/providers.tf) and can
# only succeed once Vault has been initialized
# and is unsealed. On a brand-new environment:
#
#   1. terraform apply -target=module.vault -var="configure_vault=false"
#   2. vault operator init  (one-time - save the recovery keys somewhere safe)
#      Auto-unseal via KMS means no `vault operator unseal` step is needed,
#      then or ever again after a restart.
#   3. export VAULT_TOKEN=<the initial root token, or a bootstrap token>
#   4. terraform apply -var="configure_vault=true"
#
# See the README "Vault bootstrap" section.
############################################

resource "vault_mount" "kv" {
  count = var.configure_vault ? 1 : 0

  path        = "secret"
  type        = "kv-v2"
  description = "Application, database, and API-token secrets for ${var.name_prefix}"
}

resource "vault_auth_backend" "kubernetes" {
  count = var.configure_vault ? 1 : 0
  type  = "kubernetes"
}

resource "vault_kubernetes_auth_backend_config" "this" {
  count              = var.configure_vault ? 1 : 0
  backend            = vault_auth_backend.kubernetes[0].path
  kubernetes_host    = var.kubernetes_host
  kubernetes_ca_cert = var.kubernetes_ca_cert

  # Vault validates service account tokens directly against the
  # cluster's TokenReview API - no static reviewer JWT stored anywhere.
  disable_iss_validation = true
}

resource "vault_policy" "app_read" {
  count = var.configure_vault ? 1 : 0
  name  = "${var.environment}-app-secrets-read"

  policy = <<-EOT
    path "secret/data/${var.environment}/*" {
      capabilities = ["read"]
    }
  EOT
}

resource "vault_kubernetes_auth_backend_role" "backend" {
  count                            = var.configure_vault ? 1 : 0
  backend                          = vault_auth_backend.kubernetes[0].path
  role_name                        = "backend-${var.environment}"
  bound_service_account_names      = [var.backend_service_account_name]
  bound_service_account_namespaces = ["backend-${var.environment}"]
  token_policies                   = [vault_policy.app_read[0].name]
  token_ttl                        = 3600
}

resource "vault_kubernetes_auth_backend_role" "frontend" {
  count                            = var.configure_vault ? 1 : 0
  backend                          = vault_auth_backend.kubernetes[0].path
  role_name                        = "frontend-${var.environment}"
  bound_service_account_names      = [var.frontend_service_account_name]
  bound_service_account_namespaces = ["frontend-${var.environment}"]
  token_policies                   = [vault_policy.app_read[0].name]
  token_ttl                        = 3600
}
