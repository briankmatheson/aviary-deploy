resource "helm_release" "jitsi" {
  name       = "jitsi"
  repository = "https://jitsi-contrib.github.io/jitsi-helm/"
  chart      = "jitsi-meet"
  namespace  = "jitsi"
  create_namespace = true
}
resource "kubernetes_ingress_v1" "jitsi" {
  wait_for_load_balancer = true
  metadata {
    name = "jitsi" 
    namespace = "jitsi"
    annotations = {
      "kubernetes.io/ingress.class" = "nginx"
    }
  }
  spec {
    ingress_class_name = "nginx"
    rule {
      host = "jitsi.local"
      http {
        path {
          path = "/"
          backend {
            service {
	      name = "jitsi"
              port {
		number = 80
	      }
	    }
          }
        }
      }
    }
  }
  depends_on = [
    helm_release.jitsi
  ]

}
