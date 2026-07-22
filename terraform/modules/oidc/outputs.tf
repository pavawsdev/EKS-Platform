output "lb_controller_role_arn" {
  value = aws_iam_role.lb_controller.arn
}

output "cluster_autoscaler_role_arn" {
  value = aws_iam_role.cluster_autoscaler.arn
}

output "ebs_csi_role_arn" {
  value = aws_iam_role.ebs_csi.arn
}

output "external_dns_role_arn" {
  value = aws_iam_role.external_dns.arn
}
