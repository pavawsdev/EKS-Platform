resource "kubernetes_namespace" "argocd" {
  metadata {
    name = var.namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  version    = var.argocd_chart_version

  values = [
    yamlencode({
      global = {
        domain = "argocd.${var.domain_name}"
      }
      configs = {
        params = {
          "server.insecure" = true # TLS terminated at the ALB
        }
      }
      server = {
        ingress = {
          enabled          = true
          ingressClassName = "alb"
          annotations = {
            "alb.ingress.kubernetes.io/scheme"       = "internet-facing"
            "alb.ingress.kubernetes.io/target-type"  = "ip"
            "alb.ingress.kubernetes.io/listen-ports" = jsonencode([{ HTTP = 80 }, { HTTPS = 443 }])
          }
          hosts = ["argocd.${var.domain_name}"]
        }
      }
    })
  ]

  depends_on = [kubernetes_namespace.argocd]
}

############################################
# AppProject bootstrap
# Every Application below (and everything the
# app-of-apps recurses into) references
# `project: eksplat` - previously this project
# was never actually applied anywhere (not in
# Terraform, not in any workflow), so a fresh
# ArgoCD instance had nothing for its child
# Applications to sync against until someone
# applied the AppProject manifest by hand.
# One file per environment under gitops/projects/
# (dev/stage/prod-project.yaml) so each
# environment's RBAC can be tuned independently
# later - content is identical today
# (sourceRepos/destinations aren't per-env yet).
############################################
resource "kubectl_manifest" "app_project" {
  yaml_body  = file("${path.module}/../../../gitops/projects/${var.environment}-project.yaml")
  depends_on = [helm_release.argocd]
}

############################################
# App-of-Apps bootstrap
# Points ArgoCD at this environment's own
# subfolder under gitops/environments/ - each
# environment's ArgoCD instance only ever
# recurses its own subfolder, so it can never
# construct another environment's Applications
# (e.g. dev's ArgoCD building a backend-prod
# Application pointed at prod's Vault paths).
############################################
resource "kubectl_manifest" "app_of_apps" {
  yaml_body = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name       = "app-of-apps-${var.environment}"
      namespace  = kubernetes_namespace.argocd.metadata[0].name
      finalizers = ["resources-finalizer.argocd.argoproj.io"]
    }
    spec = {
      project = "default"
      source = {
        repoURL        = var.repo_url
        targetRevision = var.target_revision
        path           = "gitops/environments/${var.environment}"
        directory = {
          recurse = true
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "argocd"
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = ["CreateNamespace=true"]
      }
    }
  })

  depends_on = [helm_release.argocd, kubectl_manifest.app_project]
}
