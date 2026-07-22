resource "aws_cognito_user_pool" "this" {
  name = "${var.name_prefix}-user-pool"

  password_policy {
    minimum_length                   = 12
    require_lowercase                = true
    require_uppercase                = true
    require_numbers                  = true
    require_symbols                  = true
    temporary_password_validity_days = 3
  }

  mfa_configuration = "OPTIONAL"

  software_token_mfa_configuration {
    enabled = true
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  auto_verified_attributes = ["email"]

  schema {
    name                = "email"
    attribute_data_type = "String"
    required            = true
    mutable             = true

    string_attribute_constraints {
      min_length = 5
      max_length = 256
    }
  }

  admin_create_user_config {
    allow_admin_create_user_only = false
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-user-pool"
  })
}

resource "aws_cognito_user_pool_domain" "this" {
  domain       = "${var.name_prefix}-${var.environment}-auth"
  user_pool_id = aws_cognito_user_pool.this.id
}

resource "aws_cognito_user_pool_client" "this" {
  name         = "${var.name_prefix}-app-client"
  user_pool_id = aws_cognito_user_pool.this.id

  generate_secret = true

  allowed_oauth_flows                 = ["code"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes                 = ["openid", "email", "profile"]

  callback_urls = length(var.callback_urls) > 0 ? var.callback_urls : ["https://app.${var.domain_name}/oauth2/callback"]
  logout_urls   = length(var.logout_urls) > 0 ? var.logout_urls : ["https://app.${var.domain_name}/"]

  supported_identity_providers = ["COGNITO"]

  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]

  prevent_user_existence_errors = "ENABLED"

  access_token_validity  = 60
  id_token_validity      = 60
  refresh_token_validity = 30

  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }
}

############################################
# App client secret -> Vault (the only durable,
# readable-by-apps copy; Terraform state still
# holds it too, so keep state encrypted/remote).
############################################
resource "vault_kv_secret_v2" "cognito" {
  count = var.configure_vault ? 1 : 0

  mount = var.vault_kv_mount
  name  = "${var.environment}/cognito"

  data_json = jsonencode({
    user_pool_id = aws_cognito_user_pool.this.id
    client_id    = aws_cognito_user_pool_client.this.id
    client_secret = aws_cognito_user_pool_client.this.client_secret
    domain        = aws_cognito_user_pool_domain.this.domain
  })
}

resource "aws_cognito_identity_pool" "this" {
  identity_pool_name              = "${var.name_prefix}-identity-pool"
  allow_unauthenticated_identities = false

  cognito_identity_providers {
    client_id               = aws_cognito_user_pool_client.this.id
    provider_name            = aws_cognito_user_pool.this.endpoint
    server_side_token_check = true
  }

  tags = var.tags
}
