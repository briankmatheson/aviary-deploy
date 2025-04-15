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
    name = "expose.ingress.tls.enabled"
    value = true
  }
  set {
    name = "expose.ingress.className"
    value = "nginx"
  }
  set {
    name = "expose.ingress.annotations[0]"
    value = "cert-manager.io/cluster-issuer: ca-issuer"
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
    helm_release.dashboard,
  ]
}
