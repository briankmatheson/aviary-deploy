resource "helm_release" "gitea" {
  name       = "gitea"
  repository = "https://dl.gitea.com/charts/"
  chart      = "gitea"
  namespace  = "gitea"
  create_namespace = true

  
  set {
    name  = "service.type"
    value = "ClusterIP"
  }
  depends_on = [
    helm_release.nfs
  ]
}
resource "kubernetes_ingress_v1" "gitea" {
  wait_for_load_balancer = true
  metadata {
    name = "gitea"
    namespace = "gitea"
    annotations = {
      "kubernetes.io/ingress.class" = "nginx"
    }
  }
  spec {
    ingress_class_name = "nginx"
    rule {
      host = "gitea.local"
      http {
        path {
          path = "/"
          backend {
            service {
	      name = "gitea-http"
              port {
		number = 3000
	      }
	    }
          }
        }
      }
    }
  }
  depends_on = [
    helm_release.nfs
  ]
}


