/* Loki (single-binary, filesystem-backed) for logs, with promtail shipping
   every pod's logs to it -- and, when loki_remote_url is set, a second copy to
   a Loki outside this cluster (the one on the management cluster: see
   by-hand/node0/logs), which still has them when this cluster is gone. Grafana gets it as the "Loki" datasource (see
   kube-prometheus-stack.tf). Scaled to one node and with the caches off — a
   homelab log store, not a cluster. */

resource "helm_release" "loki" {
  name             = "loki"
  chart            = "loki"
  version          = "7.6.0"
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
  version    = "6.17.1"
  repository = "https://grafana.github.io/helm-charts"
  namespace  = local.monitoring_ns
  timeout    = 300
  depends_on = [helm_release.loki]

  values = [yamlencode(merge({
    config = {
      clients = concat(
        [{
          url             = "http://loki.${local.monitoring_ns}.svc.cluster.local:3100/loki/api/v1/push"
          external_labels = { cluster = var.cluster_name }
        }],
        local.loki_remote ? [{
          url             = var.loki_remote_url
          external_labels = { cluster = var.cluster_name }
          basic_auth      = { username = var.loki_remote_user, password_file = "/etc/loki-remote/password" }
          tls_config      = { ca_file = "/etc/platform-ca/ca-bundle.pem" }
          backoff_config  = { max_period = "5m", max_retries = 20 }
        }] : [],
      )
    }
    }, local.loki_remote ? {
    extraVolumes = [
      { name = "loki-remote", secret = { secretName = kubernetes_secret.loki_remote[0].metadata[0].name } },
      # trust-manager's bundle (system/trust-manager.tf) carries the platform CA.
      { name = "platform-ca", configMap = { name = "xdebbie-ca-bundle" } },
    ]
    extraVolumeMounts = [
      { name = "loki-remote", mountPath = "/etc/loki-remote", readOnly = true },
      { name = "platform-ca", mountPath = "/etc/platform-ca", readOnly = true },
    ]
  } : {}))]
}

locals {
  loki_remote = var.loki_remote_url != ""
}

resource "kubernetes_secret" "loki_remote" {
  count = local.loki_remote ? 1 : 0
  metadata {
    name      = "loki-node0"
    namespace = local.monitoring_ns
  }
  data = {
    username = var.loki_remote_user
    password = var.loki_remote_password
  }
  depends_on = [helm_release.loki]
}
