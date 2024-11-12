resource "helm_release" "minio" {
  name       = "minio"
  repository = "https://operator.min.io"
  chart      = "operator"
  namespace  = "minio"
  create_namespace = true

  depends_on = [
    helm_release.nfs
  ]
}
resource "kubernetes_ingress_v1" "minio" {
  wait_for_load_balancer = true
  metadata {
    name = "minio"
    namespace = "minio"
  }
  spec {
    ingress_class_name = "nginx"
    rule {
      host = "minio.local"
      http {
        path {
          path = "/"
          backend {
            service {
	      name = "minio1-hl"
              port {
		number = 9000
	      }
	    }
          }
        }
      }
    }
    rule {
      host = "minio-console.local"
      http {
	path {
          path = "/"
          backend {
            service {
	      name = "minio1-console"
              port {
		number = 9443
	      }
	    }
          }
	}
      }
    }
  }
  depends_on = [
    helm_release.nfs,
    helm_release.ingress-nginx,
    helm_release.minio
  ]
}
