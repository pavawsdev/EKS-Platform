output "lb_controller_release_status" {
  value = helm_release.lb_controller.status
}

output "cluster_autoscaler_release_status" {
  value = helm_release.cluster_autoscaler.status
}
