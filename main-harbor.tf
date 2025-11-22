resource "helm_release" "harbor" {
  name       = "harbor"
  repository = "https://helm.goharbor.io"
  chart      = "harbor"
  namespace  = var.harbor_namespace
  create_namespace = true
  force_update = true
  
  values = [
    <<EOF
    expose.type: var.harbor_expose_type
    expose.ingress.hosts.core: var.harbor_ingress_host
    expose.ingress.className: var.harbor_ingress_class
    externalURL: var.harbor_external_url
    ipFamily.ipv6.enabled: var.harbor_ipv6_enabled
EOF
  ]

  depends_on = [
    helm_release.dashboard,
  ]
}
