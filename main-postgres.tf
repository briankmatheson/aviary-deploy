/* Percona Postgres
resource "helm_release" "postgres" {
  name       = "postgres"
  repository = "https://percona.github.io/percona-helm-charts/"
  chart      = "pg-operator"
  namespace  = "percona-postgres"
  create_namespace = true
  depends_on = [
    helm_release.dashboard,
    helm_release.ingress-nginx,
    kubernetes_storage_class.standard
  ]
}
resource "helm_release" "pgdb" {
  name       = "postgres"
  repository = "https://percona.github.io/percona-helm-charts/"
  chart      = "pg-db"
  namespace  = "percona-postgres"
  depends_on = [
    helm_release.dashboard,
    helm_release.ingress-nginx,
    helm_release.postgres
  ]
}
*/

// Zalando Postgres
resource "helm_release" "postgres" {
  name       = "postgres"
  repository = "https://opensource.zalando.com/postgres-operator/charts/postgres-operator"
  chart      = "postgres-operator"
  namespace  = "zalando-postgres"
  create_namespace = true
  depends_on = [
    helm_release.dashboard,
    helm_release.ingress-nginx,
    kubernetes_storage_class.standard
  ]
}
resource "helm_release" "postgres-ui" {
  name       = "postgres-ui"
  repository = "https://opensource.zalando.com/postgres-operator/charts/postgres-operator-ui"
  chart      = "postgres-operator-ui"
  namespace  = "zalando-postgres"
  depends_on = [
    helm_release.postgres
  ]
}
resource "kubernetes_ingress_v1" "postgres-ui" {
  wait_for_load_balancer = true
  metadata {
    name = "postgres-ui"
    namespace = "zalando-postgres"
    annotations = {
      "kubernetes.io/ingress.class" = "nginx"
      "cert-manager.io/cluster-issuer" =  "ca-issuer"
    }
  }
  spec {
    ingress_class_name = "nginx"
    rule {
      host = "postgres-ui.local"
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
      secret_name = "postgres-ui-tls"
      hosts = [ "postgres-ui.local" ]
    }
  }
  depends_on = [
    helm_release.postgres-ui
  ]
}
