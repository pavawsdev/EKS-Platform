############################################
# KMS key used for Vault auto-unseal
# (Vault still needs a one-time `vault operator
# init` after first deploy - see README - but
# never needs manual `vault operator unseal`
# again after that, even across pod restarts.)
############################################
resource "aws_kms_key" "vault_unseal" {
  description             = "Auto-unseal key for ${var.name_prefix} Vault"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  tags                    = var.tags
}

resource "aws_kms_alias" "vault_unseal" {
  name          = "alias/${var.name_prefix}-vault-unseal"
  target_key_id = aws_kms_key.vault_unseal.key_id
}

############################################
# IRSA - lets the Vault server service account
# call KMS directly, no static AWS keys anywhere
############################################
data "aws_iam_policy_document" "vault_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:${var.vault_namespace}:vault"]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "vault" {
  name               = "${var.name_prefix}-vault-irsa"
  assume_role_policy = data.aws_iam_policy_document.vault_assume.json
  tags               = var.tags
}

resource "aws_iam_policy" "vault_kms" {
  name = "${var.name_prefix}-vault-kms-unseal"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["kms:Encrypt", "kms:Decrypt", "kms:DescribeKey"]
        Resource = aws_kms_key.vault_unseal.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "vault_kms" {
  role       = aws_iam_role.vault.name
  policy_arn = aws_iam_policy.vault_kms.arn
}

############################################
# Vault namespace + Helm release
############################################
resource "kubernetes_namespace" "vault" {
  metadata {
    name = var.vault_namespace
  }
}

resource "helm_release" "vault" {
  name       = "vault"
  repository = "https://helm.releases.hashicorp.com"
  chart      = "vault"
  namespace  = kubernetes_namespace.vault.metadata[0].name
  version    = var.vault_helm_version

  values = [
    yamlencode({
      server = {
        serviceAccount = {
          annotations = {
            "eks.amazonaws.com/role-arn" = aws_iam_role.vault.arn
          }
        }
        dataStorage = {
          enabled = true
          size    = "10Gi"
        }
        # Standalone + file storage keeps this demo simple. For a real
        # prod-grade HA setup, switch to server.ha.enabled with integrated
        # Raft storage - the seal stanza below is unaffected either way.
        standalone = {
          enabled = true
          config  = <<-EOT
            ui = true
            listener "tcp" {
              address     = "[::]:8200"
              tls_disable = 1
            }
            storage "file" {
              path = "/vault/data"
            }
            seal "awskms" {
              region     = "${data.aws_region.current.name}"
              kms_key_id = "${aws_kms_key.vault_unseal.key_id}"
            }
          EOT
        }
        ingress = {
          enabled          = true
          ingressClassName = "alb"
          annotations = {
            "alb.ingress.kubernetes.io/scheme"       = "internet-facing"
            "alb.ingress.kubernetes.io/target-type"  = "ip"
            "alb.ingress.kubernetes.io/listen-ports" = jsonencode([{ HTTP = 80 }, { HTTPS = 443 }])
          }
          hosts = [
            { host = "vault.${var.domain_name}", paths = ["/"] }
          ]
        }
      }
      injector = {
        enabled = true
      }
      ui = {
        enabled = true
      }
    })
  ]

  depends_on = [kubernetes_namespace.vault]
}

data "aws_region" "current" {}
