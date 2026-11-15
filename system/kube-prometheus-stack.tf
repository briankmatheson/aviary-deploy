/* kube-prometheus-stack: Prometheus + Alertmanager + Grafana + node-exporter +
   kube-state-metrics, with the curated Kubernetes dashboard set enabled. The
   bundled Grafana is fullnameOverride'd to "grafana" so the existing gateway
   vhost (grafana.<base_domain> -> grafana:80) keeps working unchanged. Loki is
   wired in as a datasource; Node Exporter Full is pulled by grafana.com id on
   top of the chart's defaults. */

locals {
  monitoring_ns = "${var.ns_prefix}${var.grafana_namespace}"
}

resource "helm_release" "kube_prometheus_stack" {
  name             = "kube-prometheus-stack"
  chart            = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  namespace        = local.monitoring_ns
  create_namespace = true
  timeout          = 900

  values = [yamlencode({
    grafana = {
      fullnameOverride         = "grafana"
      adminPassword            = var.grafana_admin_password
      defaultDashboardsEnabled = true
      "grafana.ini" = {
        server = { root_url = "https://grafana.${var.base_domain}" }
      }
      persistence = {
        enabled          = true
        storageClassName = var.global_storage_class
        size             = "5Gi"
      }
      additionalDataSources = [{
        name   = "Loki"
        type   = "loki"
        uid    = "loki"
        url    = "http://loki.${local.monitoring_ns}.svc.cluster.local:3100"
        access = "proxy"
      }]
      dashboardProviders = {
        "dashboardproviders.yaml" = {
          apiVersion = 1
          providers = [{
            name            = "gnet"
            orgId           = 1
            folder          = "External"
            type            = "file"
            disableDeletion = false
            editable        = true
            options         = { path = "/var/lib/grafana/dashboards/gnet" }
          }]
        }
      }
      dashboards = {
        gnet = {
          node-exporter-full = { gnetId = 1860, revision = 37, datasource = "Prometheus" }
        }
      }
    }
    prometheus = {
      prometheusSpec = {
        retention = "7d"
        # watch ServiceMonitors / PodMonitors / rules in every namespace
        serviceMonitorSelectorNilUsesHelmValues = false
        podMonitorSelectorNilUsesHelmValues     = false
        ruleSelectorNilUsesHelmValues           = false
        storageSpec = {
          volumeClaimTemplate = {
            spec = {
              storageClassName = var.global_storage_class
              accessModes      = ["ReadWriteOnce"]
              resources        = { requests = { storage = "10Gi" } }
            }
          }
        }
      }
    }
    alertmanager = {
      alertmanagerSpec = {
        storage = {
          volumeClaimTemplate = {
            spec = {
              storageClassName = var.global_storage_class
              accessModes      = ["ReadWriteOnce"]
              resources        = { requests = { storage = "2Gi" } }
            }
          }
        }
      }
    }
  })]
}

# Exposure handled by the shared Envoy Gateway (grafana.<base_domain> -> grafana:80).
