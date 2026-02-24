resource "helm_release" "harbor" {
  name       = "harbor"
  repository = "https://helm.goharbor.io"
  chart      = "harbor"
  namespace  = var.harbor_namespace
  create_namespace = true
  
  values = [ <<EOF
expose:
  tls:
    auto:
      commonName: harbor.local
  type: ingress
  ingress:
    hosts:
      core: harbor.local
    className: nginx
    annotations:
      cert-manager.io/cluster-issuer: ca-issuer
      ingress.kubernetes.io/ssl-redirect: "true"
      ingress.kubernetes.io/proxy-body-size: "0"
      nginx.ingress.kubernetes.io/ssl-redirect: "true"
      nginx.ingress.kubernetes.io/proxy-body-size: "0"
  route:
    hosts:
      - harbor.local
      - harbor
      - core.harbor.local
externalURL: https://harbor.local
ipFamily.ipv6.enabled: false
EOF
  ]

  depends_on = [
    helm_release.dashboard,
  ]
}
