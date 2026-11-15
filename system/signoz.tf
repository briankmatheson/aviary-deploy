resource "helm_release" "signoz" {
  name             = "signoz"
  chart            = "signoz"
  repository       = "https://charts.signoz.io"
  namespace        = "${var.ns_prefix}${var.signoz_namespace}"
  create_namespace = true
  timeout          = 600

  values = [yamlencode({
    clickhouse = {
      persistence = {
        enabled      = true
        storageClass = var.global_storage_class
      }
    }
    zookeeper = {
      persistence = {
        enabled      = true
        storageClass = var.global_storage_class
      }
    }
    postgresql = {
      persistence = {
        enabled      = true
        storageClass = var.global_storage_class
      }
    }
  })]
}

resource "helm_release" "signoz_k8s_infra" {
  name       = "signoz-k8s-infra"
  chart      = "k8s-infra"
  repository = "https://charts.signoz.io"
  namespace  = "${var.ns_prefix}${var.signoz_namespace}"
  depends_on = [helm_release.signoz]

  values = [yamlencode({
    clusterName           = var.cluster_name
    otelCollectorEndpoint = "http://signoz-otel-collector.${var.ns_prefix}${var.signoz_namespace}.svc.cluster.local:4318"
    otelInsecure          = true
  })]
}

resource "kubernetes_manifest" "signoz_httproute" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "signoz"
      namespace = "${var.ns_prefix}${var.signoz_namespace}"
    }
    spec = {
      parentRefs = [
        {
          name      = var.gateway_name
          namespace = var.gateway_namespace
        }
      ]
      hostnames = [
        "signoz.${var.base_domain}"
      ]
      rules = [
        {
          matches = [
            {
              path = {
                type  = "PathPrefix"
                value = "/"
              }
            }
          ]
          backendRefs = [
            {
              name = "signoz"
              port = 8080
            }
          ]
        }
      ]
    }
  }

  depends_on = [helm_release.signoz]
}
