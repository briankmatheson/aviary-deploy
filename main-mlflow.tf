resource "helm_release" "mlflow" {
  name       = "mlflow"
  chart      = "mlflow"
  repository = "https://community-charts.github.io/helm-charts"
  namespace  = var.mlflow_namespace
  create_namespace = true

  depends_on = [
    helm_release.dashboard, 
  ]
}

resource "kubernetes_ingress_v1" "mlflow" {
  metadata {
    name      = "mlflow"
    namespace = var.mlflow_namespace
    annotations = {
      "kubernetes.io/ingress.class"     = var.mlflow_ingress_class
      "cert-manager.io/cluster-issuer" = var.mlflow_cluster_issuer
    }
  }
  spec {
    ingress_class_name = var.mlflow_ingress_class
    rule {
      host = var.mlflow_host
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
    tls {
      secret_name = var.mlflow_tls_secret_name
      hosts       = [var.mlflow_host]
    }
  }
  depends_on = [
    helm_release.mlflow
  ]
}
