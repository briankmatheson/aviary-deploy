# Jitsi Meet (jitsi-contrib/jitsi-helm). The web UI goes through the Gateway
# like every other app (vhost "jitsi" in system/envoy-gateway.tf); signalling
# is BOSH on the same origin, so it works under the private and public names.
# Media is UDP straight to the video bridge (JVB), which needs its own
# LoadBalancer address. JVB advertises that address and, when set,
# jitsi_public_ip -- the address outside callers reach it on, forwarded by
# bin/set-nat.sh (JVB_IP).
locals {
  jitsi_enabled = var.jitsi_enabled && var.jitsi_jvb_load_balancer_ip != ""
}

resource "helm_release" "jitsi" {
  count            = local.jitsi_enabled ? 1 : 0
  name             = "jitsi"
  repository       = "https://jitsi-contrib.github.io/jitsi-helm/"
  chart            = "jitsi-meet"
  version          = var.jitsi_chart_version
  namespace        = "${var.ns_prefix}jitsi"
  create_namespace = true

  values = [yamlencode({
    publicURL = "https://jitsi.${var.base_domain}"
    tz        = var.jitsi_timezone
    # Relative BOSH and an SCTP bridge channel instead of URLs built from
    # publicURL, so a meeting works under whichever name the page was opened.
    # (The web pod only reads these at start: restart it after changing them.)
    extraCommonEnvs = {
      BOSH_RELATIVE            = "true"
      ENABLE_COLIBRI_WEBSOCKET = "0"
      ENABLE_SCTP              = "1"
    }
    jvb = {
      publicIPs   = compact([var.jitsi_jvb_load_balancer_ip, var.jitsi_public_ip])
      disableStun = true
      service = {
        type                  = "LoadBalancer"
        externalTrafficPolicy = "Cluster"
        annotations = {
          "lbipam.cilium.io/ips" = var.jitsi_jvb_load_balancer_ip
        }
      }
    }
  })]
}
