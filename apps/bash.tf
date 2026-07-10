resource "helm_release" "bash" {
  name             = "bash"
  repository       = "https://cloudtty.github.io/cloudtty"
  chart            = "cloudtty"
  namespace        = "bash"
  create_namespace = true
}
resource "kubectl_manifest" "bash" {
  yaml_body = <<EOF
apiVersion: cloudshell.cloudtty.io/v1alpha1
kind: CloudShell
metadata:
  name: aviary-bash
  namespace: default
spec:
  exposureMode: ClusterIP
  image: nicolaka/netshoot
  commandAction: "bash"
  once: false
EOF
  depends_on = [
    helm_release.bash,
  ]
}
# Exposure handled by the shared Envoy Gateway (bash.local -> cloudshell-aviary-bash:7681).
