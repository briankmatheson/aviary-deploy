resource "helm_release" "prometheus" {
  name       = "prometheus"
  chart      = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  namespace  = "prometheus"
  create_namespace = true

  set {
    name  = "adminPassword"
    value = "admin"
  }

  depends_on = [
    helm_release.dashboard,
    helm_release.nfs,
    helm_release.ingress-nginx,
  ]
}
