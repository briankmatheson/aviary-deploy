
resource "helm_release" "rustpad" {
  name             = "rustpad"
  repository       = "oci://tccr.io/truecharts"
  chart            = "rustpad"
  namespace        = var.rustpad_namespace
  create_namespace = true


  values = [<<EOF
persistence:
  data:
    enabled: true
    mountPath: /home
    size: 4Gi
EOF
  ]
}
# Exposure handled by the shared Envoy Gateway (rustpad.local -> rustpad:3030).
