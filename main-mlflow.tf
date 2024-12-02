resource "helm_release" "mlflow" {
  name       = "mlflow"
  chart      = "mlflow"
  repository = "https://community-charts.github.io/helm-charts"
  namespace  = "mlflow"
  create_namespace = true


  depends_on = [
    helm_release.nfs,
    helm_release.ingress-nginx,
  ]
}
resource "kubernetes_ingress_v1" "mlflow" {
  wait_for_load_balancer = true
  metadata {
    name = "mlflow"
    namespace = "mlflow"
    annotations = {
      "kubernetes.io/ingress.class" = "nginx"
    }
  }
  spec {
    ingress_class_name = "nginx"
    rule {
      host = "mlflow.local"
      http {
        path {
          path = "/"
          backend {
            service {
	      name = "mlflow"
              port {
		number = 5000
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
    helm_release.mlflow
  ]
}