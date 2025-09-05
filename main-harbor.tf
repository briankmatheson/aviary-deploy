resource "helm_release" "harbor" {
  name       = "harbor"
  repository = "https://helm.goharbor.io"
  chart      = "harbor"
  namespace  = var.harbor_namespace
  create_namespace = true
  
  set {
    name  = "expose.type"
    value = var.harbor_expose_type
  }
  set {
    name  = "expose.ingress.hosts.core"
    value = var.harbor_ingress_host
  }
  set {
    name  = "expose.ingress.className"
    value = var.harbor_ingress_class
  }
  set {
    name  = "externalURL"
    value = var.harbor_external_url
  }
  set {
    name  = "ipFamily.ipv6.enabled"
    value = var.harbor_ipv6_enabled
  }
  
  depends_on = [
    helm_release.dashboard,
  ]
}
