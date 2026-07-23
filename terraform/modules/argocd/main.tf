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
# App-of-Apps bootstrap
# Points ArgoCD at the argocd/applications
# folder in this same repo, one Application
# per environment/service.
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
        path           = "argocd/applications"
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

  depends_on = [helm_release.argocd]
}
