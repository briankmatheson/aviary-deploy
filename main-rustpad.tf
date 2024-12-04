resource "helm_release" "rustpad" {
  name       = "rustpad"
  repository = "oci://tccr.io/truecharts"
  chart      = "rustpad"
  namespace  = "rustpad"
  create_namespace = true
}
resource "kubernetes_ingress_v1" "rustpad" {
  wait_for_load_balancer = true
  metadata {
    name = "rustpad" 
    namespace = "rustpad"
    annotations = {
      "kubernetes.io/ingress.class" = "nginx"
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
  }
}
