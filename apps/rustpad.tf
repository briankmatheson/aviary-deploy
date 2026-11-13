resource "helm_release" "rustpad" {
  name             = "rustpad"
  repository       = "oci://tccr.io/truecharts"
  chart            = "rustpad"
  namespace        = var.rustpad_namespace
  create_namespace = true

  values = [yamlencode({
    persistence = {
      data = {
        enabled      = true
        mountPath    = "/home"
        size         = "${var.rustpad_pvc_size}Gi"
        storageClass = var.global_storage_class
      }
    }
  })]
}
# Exposure handled by the shared Envoy Gateway (rustpad.local -> rustpad:3030).
