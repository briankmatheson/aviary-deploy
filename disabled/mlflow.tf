# DISABLED. These resources still use the old nginx Ingress and their own
# *_ingress_class/_host/_tls variables (declared below). To enable: move the
# file into apps/, system/ or data/, replace the Ingress with an entry in
# local.vhosts (system/envoy-gateway.tf), and drop the variables you no
# longer need.

variable "mlflow_namespace" { default = "mlflow" }
variable "mlflow_host" { default = "mlflow.local" }
variable "mlflow_tls_secret_name" { default = "mlflow-tls" }
variable "mlflow_ingress_class" { default = "nginx" }
variable "mlflow_cluster_issuer" { default = "ca-issuer" }

resource "helm_release" "mlflow" {
  name             = "mlflow"
  chart            = "mlflow"
  repository       = "https://community-charts.github.io/helm-charts"
  namespace        = var.mlflow_namespace
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
      "kubernetes.io/ingress.class"    = var.mlflow_ingress_class
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
