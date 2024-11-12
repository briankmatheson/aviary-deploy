resource "helm_release" "drone" {
  name       = "drone"
  repository = "https://charts.drone.io"
  chart      = "drone"
  namespace  = "drone"
  create_namespace = true

  set {
    name = "ingress.enabled"
    value = true
  }
  set {
    name = "ingress.hosts[0]"
    value = "drone.local"
  }
  set {
    name = "env.DRONE_SERVER_HOST"
    value = "drone.local"
  }
  depends_on = [
    helm_release.nfs
  ]
}
