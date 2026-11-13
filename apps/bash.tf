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
  # No custom image: cloudtty >= 0.8 execs /usr/lib/ttyd/startup.sh inside the
  # worker, which only its own cloudshell image provides.
  commandAction: "bash"
  once: false
EOF
  depends_on = [
    helm_release.bash,
  ]
}
# cloudtty >= 0.8 names the worker pod/Service randomly (cloudshell-worker-xxxx),
# so give the HTTPRoute a stable Service that selects the worker by owner label.
resource "kubectl_manifest" "bash_svc" {
  yaml_body  = <<EOF
apiVersion: v1
kind: Service
metadata:
  name: cloudshell-aviary-bash
  namespace: default
spec:
  selector:
    worker.cloudtty.io/owner-name: aviary-bash
  ports:
    - port: 7681
      targetPort: 7681
EOF
  depends_on = [kubectl_manifest.bash]
}
# Exposure handled by the shared Envoy Gateway (bash.<base_domain> -> cloudshell-aviary-bash:7681).
