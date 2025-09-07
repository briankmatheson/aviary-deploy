resource "helm_release" "harbor" {
  name       = "harbor"
  repository = "https://helm.goharbor.io"
  chart      = "harbor"
  namespace  = var.harbor_namespace
  create_namespace = true

  values = [
    <<EOF
     expose.type = "ingress"
     expose.ingress.className = "nginx"
     expose.ingress.hosts.core = "harbor.local"
     ipv6.enabled = false
EOF
  ]

  depends_on = [
    helm_release.dashboard,
  ]
}
