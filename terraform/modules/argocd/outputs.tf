output "argocd_namespace" {
  value = kubernetes_namespace.argocd.metadata[0].name
}

output "argocd_server_url" {
  value = "https://argocd.${var.domain_name}"
}
