resource "helm_release" "harbor" {
  name       = "harbor"
  repository = "https://helm.goharbor.io"
  chart      = "harbor"
  namespace  = "harbor"
  create_namespace = true

  set {
    name = "expose.type"
    value = "ingress"
  }
  set {
    name = "expose.ingress.hosts.core"
    value = "harbor"
  }
  set {
    name = "expose.ingress.className"
    value = "nginx"
  }
  set {
    name = "externalURL"
    value = "https://harbor"
  }
  set {
    name = "ipFamily.ipv6.enabled"
    value = false
  }
  depends_on = [
    helm_release.nfs,
    helm_release.ingress-nginx
  ]
}
