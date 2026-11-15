/* Loki (single-binary, filesystem-backed) for logs, with promtail shipping
   every pod's logs to it. Grafana gets it as the "Loki" datasource (see
   kube-prometheus-stack.tf). Scaled to one node and with the caches off — a
   homelab log store, not a cluster. */

resource "helm_release" "loki" {
  name             = "loki"
  chart            = "loki"
  repository       = "https://grafana.github.io/helm-charts"
  namespace        = local.monitoring_ns
  create_namespace = true
  timeout          = 600

  values = [yamlencode({
    deploymentMode = "SingleBinary"
    loki = {
      auth_enabled = false
      commonConfig = { replication_factor = 1 }
      storage      = { type = "filesystem" }
      schemaConfig = {
        configs = [{
          from         = "2024-04-01"
          store        = "tsdb"
          object_store = "filesystem"
          schema       = "v13"
          index        = { prefix = "loki_index_", period = "24h" }
        }]
      }
      limits_config = {
        retention_period          = "168h"
        allow_structured_metadata = true
      }
    }
    singleBinary = {
      replicas    = 1
      persistence = { enabled = true, storageClass = var.global_storage_class, size = "10Gi" }
    }
    # one node, no microservice split, no caches
    read         = { replicas = 0 }
    write        = { replicas = 0 }
    backend      = { replicas = 0 }
    chunksCache  = { enabled = false }
    resultsCache = { enabled = false }
    lokiCanary   = { enabled = false }
    test         = { enabled = false }
    gateway      = { enabled = false }
    minio        = { enabled = false }
  })]
}

resource "helm_release" "promtail" {
  name       = "promtail"
  chart      = "promtail"
  repository = "https://grafana.github.io/helm-charts"
  namespace  = local.monitoring_ns
  timeout    = 300
  depends_on = [helm_release.loki]

  values = [yamlencode({
    config = {
      clients = [{ url = "http://loki.${local.monitoring_ns}.svc.cluster.local:3100/loki/api/v1/push" }]
    }
  })]
}
