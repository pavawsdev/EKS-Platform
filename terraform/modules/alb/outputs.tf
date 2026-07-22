output "alb_security_group_id" {
  value = aws_security_group.alb.id
}

output "acm_certificate_arn" {
  value = var.create_acm_certificate ? aws_acm_certificate.this[0].arn : ""
}

output "waf_web_acl_arn" {
  value = var.enable_waf ? aws_wafv2_web_acl.this[0].arn : ""
}
