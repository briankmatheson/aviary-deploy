resource "helm_release" "harbor" {
  name             = "harbor"
  repository       = "https://helm.goharbor.io"
  chart            = "harbor"
  namespace        = var.harbor_namespace
  create_namespace = true

  values = [<<EOF
# TLS terminates at the Envoy Gateway; expose the core as a plain ClusterIP
# Service and route to it via HTTPRoute (see envoy-gateway.tf).
expose:
  type: clusterIP
  tls:
    enabled: false
externalURL: https://harbor.local
ipFamily.ipv6.enabled: false
EOF
  ]
}
