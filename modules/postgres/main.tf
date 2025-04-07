/* Percona Postgres */
resource "helm_release" "postgres" {
  name       = "postgres"
  repository = "https://percona.github.io/percona-helm-charts/"
  chart      = "pg-operator"
  namespace  = var.percona_postgres_namespace
  create_namespace = true
}
resource "helm_release" "pgdb" {
  name       = "postgres"
  repository = "https://percona.github.io/percona-helm-charts/"
  chart      = "pg-db"
  namespace  = var.percona_postgres_namespace
  depends_on = [
    helm_release.postgres
  ]
}

/* Zalando Postgres */
resource "helm_release" "zalando_postgres" {
  name       = "postgres"
  repository = "https://opensource.zalando.com/postgres-operator/charts/postgres-operator"
  chart      = "postgres-operator"
  namespace  = var.zalando_postgres_namespace
  create_namespace = true
}
resource "helm_release" "postgres-ui" {
  name       = "postgres-ui"
  repository = "https://opensource.zalando.com/postgres-operator/charts/postgres-operator-ui"
  chart      = "postgres-operator-ui"
  namespace  = var.zalando_postgres_namespace
  depends_on = [
    helm_release.postgres
  ]
}
resource "kubernetes_ingress_v1" "postgres-ui" {
  metadata {
    name = "postgres-ui"
    namespace = var.zalando_postgres_namespace
    annotations = {
      "kubernetes.io/ingress.class" = var.zalando_postgres_ui_ingress_class
      "cert-manager.io/cluster-issuer" = "ca-issuer"
    }
  }
  spec {
    ingress_class_name = var.zalando_postgres_ui_ingress_class
    rule {
      host = var.zalando_postgres_ui_ingress_host
      http {
        path {
          path = "/"
          backend {
            service {
              name = "postgres-ui-postgres-operator-ui"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
    tls {
      secret_name = var.zalando_postgres_ui_tls_secret_name
      hosts = [var.zalando_postgres_ui_ingress_host]
    }
  }
  depends_on = [
    helm_release.postgres-ui
  ]
}
