resource "helm_release" "harbor" {
  name       = "harbor"
  repository = "https://helm.goharbor.io"
  chart      = "harbor"
  namespace  = var.harbor_namespace
  create_namespace = true

  values = [
    <<EOF
    expose.type: value = var.harbor_expose_type
    expose.ingress.hosts.core: value = var.harbor_ingress_host
    expose.ingress.className: value = var.harbor_ingress_class
    externalURL: value = var.harbor_external_url
    ipFamily.ipv6.enabled: value = var.harbor_ipv6_enabled
EOF
  ]

  depends_on = [
    helm_release.dashboard,
  ]
}
