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
resource "kubectl_manifest" "db" {
  yaml_body = <<EOF
apiVersion: apiextensions.k8s.io/v1
kind: perconapgcluster
metadata:
  name: db
  namespace: percona-postgres
spec:
  postgresqlVersion: "15"
  instances:
  - name: primary
    storage:
      accessModes: 
        - ReadWriteOnce
      size: 10Gi
  - name: standby
    storage:
      accessModes: 
        - ReadWriteOnce
      size: 10Gi
EOF
  depends_on = [
    helm_release.postgres
  ]
}
