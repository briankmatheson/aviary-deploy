resource "helm_release" "rustpad" {
  name       = "rustpad"
  repository = "oci://tccr.io/truecharts"
  chart      = "rustpad"
  namespace  = var.rustpad_namespace
  create_namespace = true
}
resource "kubernetes_ingress_v1" "rustpad" {
  metadata {
    name = "rustpad" 
    namespace = var.rustpad_namespace
    annotations = {
      "kubernetes.io/ingress.class" = var.rustpad_ingress_class
      "cert-manager.io/cluster-issuer" = "ca-issuer"
    }
  }
  spec {
    ingress_class_name = var.rustpad_ingress_class
    rule {
      host = var.rustpad_ingress_host
      http {
        path {
          path = "/"
          backend {
            service {
              name = "rustpad"
              port {
                number = 3030
              }
            }
          }
        }
      }
    }
    tls {
      secret_name = var.rustpad_tls_secret_name
      hosts = [var.rustpad_ingress_host]
    }
  }
  depends_on = [
    helm_release.rustpad,
  ]
}

