############################################
# Amazon Managed Prometheus (AMP) - Kubernetes
# and application metrics storage.
############################################
resource "aws_prometheus_workspace" "this" {
  alias = "${var.name_prefix}-amp"
  tags  = var.tags
}

############################################
# Amazon Managed Grafana - dashboard layer.
# SERVICE_MANAGED lets AWS create and keep in
# sync the IAM role/policy this workspace uses
# to query its data sources, rather than us
# hand-rolling and maintaining that ourselves
# (same "trust the AWS-managed surface" choice
# already made for ebs_csi's IRSA policy).
#
# User login (AWS_SSO) requires IAM Identity
# Center to be enabled on this account - it
# is not, as of writing (confirmed via
# `aws sso-admin list-instances`). Enabling it
# and assigning a user/group to this workspace
# is a one-time manual step - see README
# "Observability". No aws_grafana_role_association
# here since it needs a real SSO user ID that
# doesn't exist until that step happens.
############################################
resource "aws_grafana_workspace" "this" {
  name                     = "${var.name_prefix}-grafana"
  account_access_type      = "CURRENT_ACCOUNT"
  authentication_providers = ["AWS_SSO"]
  permission_type          = "SERVICE_MANAGED"
  data_sources             = ["PROMETHEUS", "CLOUDWATCH", "XRAY"]
  tags                     = var.tags
}

############################################
# CloudWatch Container Insights (logs + metrics)
# via the AWS-managed EKS addon - same
# aws_eks_addon pattern already used in
# terraform/modules/eks/main.tf for
# vpc-cni/coredns/kube-proxy/aws-ebs-csi-driver.
#
# service_account_role_arn assumes the addon's
# default service account is amazon-cloudwatch/
# cloudwatch-agent (see the matching IRSA trust
# condition in terraform/modules/oidc/main.tf) -
# unverified against the specific addon version
# EKS resolves for this cluster version. Confirm
# with `aws eks describe-addon-configuration`
# before ever setting enable_observability=true
# for real.
############################################
resource "aws_eks_addon" "cloudwatch_observability" {
  cluster_name             = var.cluster_name
  addon_name               = "amazon-cloudwatch-observability"
  service_account_role_arn = var.cloudwatch_observability_role_arn
  tags                     = var.tags
}

############################################
# ADOT (AWS Distro for OpenTelemetry) - installs
# only the OpenTelemetry Operator. No IRSA here:
# the operator pod itself makes no AWS calls: it
# just manages OpenTelemetryCollector CRs. AWS
# permissions belong on the collector instance
# below, whose service account we create and
# control directly.
############################################
resource "aws_eks_addon" "adot" {
  cluster_name = var.cluster_name
  addon_name   = "adot"
  tags         = var.tags
}

resource "kubernetes_namespace" "adot_collector" {
  metadata {
    name = "adot-collector"
  }
}

resource "kubernetes_service_account" "adot_collector" {
  metadata {
    name      = "adot-collector"
    namespace = kubernetes_namespace.adot_collector.metadata[0].name
    annotations = {
      "eks.amazonaws.com/role-arn" = var.adot_collector_role_arn
    }
  }
}

# aps:RemoteWrite is attached here, not in the oidc
# module, because this is the first point in the
# module graph where the real AMP workspace ARN
# exists - avoids an unscoped Resource="*" grant.
# The X-Ray half of this role's permissions is
# already attached in the oidc module (X-Ray trace
# ingestion has no resource-level ARNs to scope to).
resource "aws_iam_policy" "adot_collector_aps" {
  name = "${var.name_prefix}-adot-collector-aps-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["aps:RemoteWrite"]
        Resource = aws_prometheus_workspace.this.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "adot_collector_aps" {
  role       = var.adot_collector_role_name
  policy_arn = aws_iam_policy.adot_collector_aps.arn
}

# The Prometheus receiver's kubernetes_sd_configs needs
# cluster-wide read RBAC that neither the adot addon nor
# the OpenTelemetry Operator grants automatically - a
# real, easy-to-miss upstream gap, not specific to this repo.
resource "kubectl_manifest" "adot_collector_rbac_role" {
  yaml_body = yamlencode({
    apiVersion = "rbac.authorization.k8s.io/v1"
    kind       = "ClusterRole"
    metadata = {
      name = "adot-collector"
    }
    rules = [
      {
        apiGroups = [""]
        resources = ["pods", "nodes", "endpoints", "namespaces"]
        verbs     = ["get", "list", "watch"]
      },
      {
        apiGroups = [""]
        resources = ["nodes/proxy"]
        verbs     = ["get"]
      }
    ]
  })

  depends_on = [aws_eks_addon.adot]
}

resource "kubectl_manifest" "adot_collector_rbac_binding" {
  yaml_body = yamlencode({
    apiVersion = "rbac.authorization.k8s.io/v1"
    kind       = "ClusterRoleBinding"
    metadata = {
      name = "adot-collector"
    }
    subjects = [
      {
        kind      = "ServiceAccount"
        name      = kubernetes_service_account.adot_collector.metadata[0].name
        namespace = kubernetes_namespace.adot_collector.metadata[0].name
      }
    ]
    roleRef = {
      apiGroup = "rbac.authorization.k8s.io"
      kind     = "ClusterRole"
      name     = "adot-collector"
    }
  })

  depends_on = [kubectl_manifest.adot_collector_rbac_role]
}

# The OpenTelemetryCollector CR itself: receives traces
# (X-Ray daemon protocol on UDP :2000 - what the Node.js
# aws-xray-sdk-core speaks by default, so app code needs
# no trace-protocol changes - plus OTLP for future use)
# and scrapes Prometheus metrics from pods annotated
# prometheus.io/scrape=true (see helm/backend and
# helm/worker's observability.enabled toggle), exporting
# traces to X-Ray and metrics to this AMP workspace.
#
# apiVersion assumes the OpenTelemetry Operator version
# the pinned "adot" addon ships uses the v1beta1 CRD schema
# (structured spec.config) rather than the older v1alpha1
# (raw string spec.config) - unverified, flagged in the plan.
resource "kubectl_manifest" "adot_collector" {
  yaml_body = yamlencode({
    apiVersion = "opentelemetry.io/v1beta1"
    kind       = "OpenTelemetryCollector"
    metadata = {
      name      = "adot-collector"
      namespace = kubernetes_namespace.adot_collector.metadata[0].name
    }
    spec = {
      mode           = "deployment"
      serviceAccount = kubernetes_service_account.adot_collector.metadata[0].name
      config = {
        receivers = {
          awsxray = {
            endpoint  = "0.0.0.0:2000"
            transport = "udp"
          }
          otlp = {
            protocols = {
              grpc = { endpoint = "0.0.0.0:4317" }
              http = { endpoint = "0.0.0.0:4318" }
            }
          }
          prometheus = {
            config = {
              scrape_configs = [
                {
                  job_name              = "kubernetes-pods"
                  kubernetes_sd_configs = [{ role = "pod" }]
                  relabel_configs = [
                    {
                      source_labels = ["__meta_kubernetes_pod_annotation_prometheus_io_scrape"]
                      action        = "keep"
                      regex         = "true"
                    },
                    {
                      source_labels = ["__meta_kubernetes_pod_annotation_prometheus_io_path"]
                      action        = "replace"
                      target_label  = "__metrics_path__"
                      regex         = "(.+)"
                    },
                    {
                      source_labels = ["__address__", "__meta_kubernetes_pod_annotation_prometheus_io_port"]
                      action        = "replace"
                      regex         = "([^:]+)(?::\\d+)?;(\\d+)"
                      replacement   = "$1:$2"
                      target_label  = "__address__"
                    },
                    {
                      source_labels = ["__meta_kubernetes_namespace"]
                      action        = "replace"
                      target_label  = "namespace"
                    },
                    {
                      source_labels = ["__meta_kubernetes_pod_name"]
                      action        = "replace"
                      target_label  = "pod"
                    }
                  ]
                }
              ]
            }
          }
        }
        processors = {
          batch = {}
        }
        exporters = {
          awsxray = {
            region = var.aws_region
          }
          awsprometheusremotewrite = {
            endpoint = "${aws_prometheus_workspace.this.prometheus_endpoint}api/v1/remote_write"
            aws_auth = {
              region  = var.aws_region
              service = "aps"
            }
          }
        }
        service = {
          pipelines = {
            traces = {
              receivers  = ["awsxray", "otlp"]
              processors = ["batch"]
              exporters  = ["awsxray"]
            }
            metrics = {
              receivers  = ["prometheus"]
              processors = ["batch"]
              exporters  = ["awsprometheusremotewrite"]
            }
          }
        }
      }
    }
  })

  depends_on = [aws_eks_addon.adot, kubectl_manifest.adot_collector_rbac_binding]
}
