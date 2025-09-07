resource "helm_release" "harbor" {
  name       = "harbor"
  repository = "https://helm.goharbor.io"
  chart      = "harbor"
  namespace  = var.harbor_namespace
  create_namespace = true

  values = [
    <<EOF
ingress.className: "nginx"
expose.ingress.className: "nginx"
ingress.hosts.core: "harbor.local"
expose.ingress.hosts.core: "harbor.local"
ipv6.enabled: false
externalURL: https://harbor.local
harborAdminPassword: admin


EOF
  ]

  depends_on = [
    helm_release.dashboard,
  ]
}
