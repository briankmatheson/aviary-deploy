resource "helm_release" "grafana" {
  name             = "grafana"
  chart            = "grafana"
  repository       = "https://grafana.github.io/helm-charts"
  namespace        = var.grafana_namespace
  create_namespace = true

  values = [
    <<EOF
adminPassword: admin
persistence:
  enabled: true
useStatefulSet: true
EOF
  ]

  depends_on = [
    helm_release.prometheus,
  ]
}

resource "kubernetes_ingress_v1" "grafana" {
  metadata {
    name      = "grafana"
    namespace = var.grafana_namespace
    annotations = merge(
      local.default_annotations,
      {
        "cert-manager.io/cluster-issuer" = var.cluster_issuer
      }
    )
  }

  spec {
    ingress_class_name = var.ingress_class

    rule {
      host = var.grafana_host
      http {
        path {
          path = "/"
          backend {
            service {
              name = "grafana"
              port {
                number = 80
              }
            }
          }
        }
      }
    }

    tls {
      secret_name = var.grafana_tls_secret_name
      hosts       = [var.grafana_host]
    }
  }

  depends_on = [
    helm_release.grafana
  ]
}
