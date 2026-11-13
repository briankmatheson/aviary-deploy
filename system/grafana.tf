resource "helm_release" "grafana" {
  name             = "grafana"
  chart            = "grafana"
  repository       = "https://grafana.github.io/helm-charts"
  namespace        = var.grafana_namespace
  create_namespace = true

  values = [yamlencode({
    adminPassword = var.grafana_admin_password
    persistence = {
      enabled          = true
      storageClassName = var.global_storage_class
    }
    useStatefulSet = true
  })]
}

# Exposure handled by the shared Envoy Gateway (grafana.<base_domain> -> grafana:80).
