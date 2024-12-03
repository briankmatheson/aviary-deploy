resource "helm_release" "mattermost" {
  name       = "mattermost"
  repository = "https://helm.mattermost.com"
  chart      = "mattermost-operator"
  namespace  = "mattermost"
  create_namespace = true
  depends_on = [
    helm_release.nfs
  ]
}
resource "kubectl_manifest" "mattermost" {
  yaml_body = <<EOF
apiVersion: installation.mattermost.com/v1beta1
kind: Mattermost
metadata:
  name: mattermost
  namespace: mattermost
spec:
  ingress:
    enabled: true
    host: mattermost.local
    ingressAnnotations:
      kubernetes.io/ingress.class: nginx
EOF
  depends_on = [
    helm_release.mattermost,
    helm_release.ingress-nginx
  ]
}
