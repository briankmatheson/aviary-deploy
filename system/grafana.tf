resource "helm_release" "grafana" {
  name             = "grafana"
  chart            = "grafana"
  repository       = "https://grafana.github.io/helm-charts"
  namespace        = var.grafana_namespace
  create_namespace = true

  values = [
    <<EOF
adminPassword: admin
persistence:
  enabled: true
useStatefulSet: true
EOF
  ]
}

# Exposure handled by the shared Envoy Gateway (grafana.local -> grafana:80).
