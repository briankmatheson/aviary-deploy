/* Percona Postgres */
resource "helm_release" "postgres" {
  name             = "postgres"
  repository       = "https://percona.github.io/percona-helm-charts/"
  chart            = "pg-operator"
  namespace        = var.percona_postgres_namespace
  create_namespace = true
}

/* Zalando Postgres */
resource "helm_release" "zalando_postgres" {
  name             = "postgres"
  repository       = "https://opensource.zalando.com/postgres-operator/charts/postgres-operator"
  chart            = "postgres-operator"
  namespace        = var.zalando_postgres_namespace
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
# Exposure handled by the shared Envoy Gateway
# (postgres-ui.local -> postgres-ui-postgres-operator-ui:80).
