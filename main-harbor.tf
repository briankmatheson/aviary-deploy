resource "helm_release" "harbor" {
  name       = "harbor"
  repository = "https://helm.goharbor.io"
  chart      = "harbor"
  namespace  = var.harbor_namespace
  create_namespace = true
  
  values = [ <<EOF
expose:
  tls:
    auto:
      commonName: harbor.local
  type: ingress
  ingress:
    hosts:
      core: harbor.local
    className: nginx
    annotations:
      cert-manager.io/cluster-issuer: ca-issuer
      ingress.kubernetes.io/ssl-redirect: "true"
      ingress.kubernetes.io/proxy-body-size: "0"
      nginx.ingress.kubernetes.io/ssl-redirect: "true"
      nginx.ingress.kubernetes.io/proxy-body-size: "0"
  route:
    hosts:
      - harbor.local
      - harbor
      - core.harbor.local
externalURL: https://harbor.local
ipFamily.ipv6.enabled: false
EOF
  ]

  depends_on = [
    helm_release.dashboard,
  ]
}
/*
resource "kubernetes_ingress_v1" "harbor" {
  metadata {
    name      = "harbor"
    namespace = var.harbor_namespace
    annotations = merge(
      local.default_annotations,
      {
        "cert-manager.io/cluster-issuer" = var.harbor_cluster_issuer
      }
    )
  }

  spec {
    ingress_class_name = var.harbor_ingress_class

    rule {
      host = var.harbor_ingress_host
      http {
        path {
          path = "/api/"
	  path_type = "Prefix"
          backend {
            service {
              name = "harbor-core"
              port {
                number = 80
              }
            }
          }
        }
        path {
          path = "/service/"
	  path_type = "Prefix"
          backend {
            service {
              name = "harbor-core"
              port {
                number = 80
              }
            }
          }
        }
        path {
          path = "/v2/"
	  path_type = "Prefix"
          backend {
            service {
              name = "harbor-core"
              port {
                number = 80
              }
            }
          }
        }
        path {
          path = "/c/"
	  path_type = "Prefix"
          backend {
            service {
              name = "harbor-core"
              port {
                number = 80
              }
            }
          }
        }
        path {
          path = "/"
	  path_type = "Prefix"
          backend {
            service {
              name = "harbor-portal"
              port {
                number = 80
              }
            }
          }
        }
      }
    }

    tls {
      secret_name = "harbor-tls"
      hosts       = [var.harbor_ingress_host]
    }
  }

  depends_on = [
    helm_release.harbor
  ]
}
*/
