# Kubeshark: live view of the traffic between the cluster's pods (HTTP, DNS,
# and the rest), for debugging. A worker DaemonSet captures on every node, the
# hub collects, and the front end is the web page -- served at
# kubeshark.<base_domain> by the shared Envoy Gateway (see envoy-gateway.tf).
#
# The workers are privileged and use the host network (packet capture and
# eBPF), and the page shows other apps' traffic in the clear, tokens and
# all: keep it off the public Gateway and behind the Gitea login.

resource "helm_release" "kubeshark" {
  name             = "kubeshark"
  repository       = "https://helm.kubeshark.com"
  chart            = "kubeshark"
  version          = "53.6.0"
  namespace        = "${var.ns_prefix}kubeshark"
  create_namespace = true

  values = [yamlencode({
    tap = {
      # The chart is told its own release namespace here, not by Helm.
      release = { namespace = "${var.ns_prefix}kubeshark" }
      # Routed by the Gateway, not an Ingress.
      ingress = { enabled = false }
      # Nothing about this cluster's traffic is reported upstream.
      telemetry = { enabled = false }
    }
  })]
}
