resource "helm_release" "postgres" {
  name       = "postgres"
  repository = "https://percona.github.io/percona-helm-charts/"
  chart      = "pg-operator"
  namespace  = "percona-postgres"
  create_namespace = true
  depends_on = [
    helm_release.nfs
  ]
}
