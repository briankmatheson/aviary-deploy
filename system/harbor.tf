resource "helm_release" "harbor" {
  name             = "harbor"
  repository       = "https://helm.goharbor.io"
  chart            = "harbor"
  namespace        = var.harbor_namespace
  create_namespace = true

  # TLS terminates at the Envoy Gateway; expose the core as a plain ClusterIP
  # Service and route to it via HTTPRoute (see envoy-gateway.tf).
  values = [yamlencode({
    expose = {
      type = "clusterIP"
      tls  = { enabled = false }
    }
    externalURL = var.harbor_external_url
    ipFamily    = { ipv6 = { enabled = var.harbor_ipv6_enabled } }
  })]
}
