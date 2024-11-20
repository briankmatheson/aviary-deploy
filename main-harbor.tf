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
    name = "expose.ingress.annotations"
    value = "kubernetes.io/ingress.class: nginx"
  }
  set {
    name = "expose.ingress.hosts.core"
    value = "harbor"
  }
  set {
    name = "externalURL"
    value = "https://harbor"
  }
  depends_on = [
    helm_release.nfs,
    helm_release.ingress-nginx
  ]
}
