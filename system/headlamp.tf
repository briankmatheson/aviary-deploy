# Headlamp replaces the Kubernetes Dashboard as the cluster UI.
# Exposure is handled by the shared Envoy Gateway (see envoy-gateway.tf); the
# headlamp.local HTTPRoute is generated from local.vhosts there.
resource "helm_release" "headlamp" {
  name             = "headlamp"
  repository       = "https://kubernetes-sigs.github.io/headlamp/"
  chart            = "headlamp"
  namespace        = "headlamp"
  create_namespace = true
}
