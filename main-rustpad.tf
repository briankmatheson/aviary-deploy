resource "helm_release" "rustpad" {
  name       = "rustpad"
  repository = "oci://tccr.io/truecharts"
  chart      = "rustpad"
  namespace  = "rustpad"
  create_namespace = true
  depends_on = [
    helm_release.dashboard,
    helm_release.ingress-nginx
  ]
}
resource "kubernetes_ingress_v1" "rustpad" {
  wait_for_load_balancer = true
  metadata {
    name = "rustpad" 
    namespace = "rustpad"
    annotations = {
      "kubernetes.io/ingress.class" = "nginx"
      "cert-manager.io/cluster-issuer" =  "ca-issuer"
    }
  }
  spec {
    ingress_class_name = "nginx"
    rule {
      host = "rustpad.local"
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
      secret_name = "rustpad-tls"
      hosts = ["rustpad.local"]
    }
  }
  depends_on = [
    helm_release.rustpad,
  ]
}

