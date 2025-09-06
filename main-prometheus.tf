resource "helm_release" "prometheus" {
  name       = "prometheus"
  chart      = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  namespace  = var.prometheus_namespace
  create_namespace = true
  values = [
    <<EOF
adminPassword: var.prometheus_admin_password
EOF
  ]

  depends_on = [
    helm_release.dashboard,
  ]
}
