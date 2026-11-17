# Envoy Gateway replaces ingress-nginx as the cluster's north-south entry point.
#
# It implements the Kubernetes Gateway API: a single shared Gateway ("aviary")
# terminates TLS and every app attaches an HTTPRoute to it. All Gateway API
# objects are applied with kubectl_manifest (like aviary-frontend.tf) so the
# CRDs -- which the envoy-gateway chart installs -- are not required at plan time.
#
# TLS: certificates terminate at the Gateway. Each HTTPS listener references an
# <app>-tls Secret in the Gateway namespace, and the Gateway is annotated with a
# cert-manager cluster-issuer so cert-manager's gateway-shim provisions them.
# THIS REQUIRES cert-manager to run with Gateway API support enabled:
#   helm value:  config.enableGatewayAPI=true
#   (equivalently --feature-gates=ExperimentalGatewayAPISupport=true)

locals {
  # Namespace that holds the shared Gateway and its TLS secrets.
  gateway_namespace = "envoy-gateway"

  # Second Gateway on its own fixed address, for traffic NATed in from
  # outside. Created only when nat_gateway_ip is set.
  nat_gateway_name    = "aviary-nat"
  nat_gateway_enabled = var.nat_gateway_ip != ""

  # With public_domain set, the public Gateway serves each vhost as
  # <key>.<public_domain> (gitea.example.org; the landing page is
  # aviary.<public_domain>, leaving the bare domain free) on its own
  # <key>-public-tls certificate from public_cluster_issuer. Unset, it serves
  # the same hostnames and certificates as the private Gateway.
  public_domain_enabled = local.nat_gateway_enabled && var.public_domain != ""
  # The public names need a CA outside clients trust: unless told otherwise,
  # the Let's Encrypt issuer below.
  letsencrypt_enabled   = local.public_domain_enabled && var.public_cluster_issuer == ""
  public_cluster_issuer = var.public_cluster_issuer != "" ? var.public_cluster_issuer : "letsencrypt"
  public_vhosts = { for k, v in local.vhosts : k => {
    host = local.public_domain_enabled ? "${k}.${var.public_domain}" : v.host
    tls  = local.public_domain_enabled ? "${k}-public-tls" : v.tls
  } }

  # host -> backend Service routing table. One HTTPS listener and one HTTPRoute
  # are generated per entry. `namespace`/`service`/`port` identify the backend.
  # `group` is where the landing page lists the entry: "apps" (things people
  # open to do work) on top, "system" (platform plumbing) below. It is stamped
  # on the HTTPRoute as the aviary/group label, which aviary-frontend reads.
  jitsi_vhost = var.jitsi_enabled && var.jitsi_jvb_load_balancer_ip != "" ? {
    jitsi = { host = "jitsi.${var.base_domain}", namespace = "${var.ns_prefix}jitsi", service = "jitsi-jitsi-meet-web", port = 8000, tls = "jitsi-tls", group = "apps" }
  } : {}
  vhosts = merge(local.axigen_vhost, local.jitsi_vhost, {
    argo       = { host = "argo.${var.base_domain}", namespace = "${var.ns_prefix}argo", service = "argo-argocd-server", port = 80, tls = "argo-tls", group = "apps" }
    aviary     = { host = var.base_domain, namespace = "aviary", service = "aviary-frontend", port = 8086, tls = "aviary-tls", group = "apps" }
    bash       = { host = "bash.${var.base_domain}", namespace = "default", service = "cloudshell-aviary-bash", port = 7681, tls = "bash-tls", group = "system" }
    drone      = { host = "drone.${var.base_domain}", namespace = "${var.ns_prefix}drone", service = "drone", port = 8080, tls = "drone-tls", group = "apps" }
    rustpad    = { host = "rustpad.${var.base_domain}", namespace = "${var.ns_prefix}${var.rustpad_namespace}", service = "rustpad", port = 3030, tls = "rustpad-tls", group = "apps" }
    grafana    = { host = "grafana.${var.base_domain}", namespace = "${var.ns_prefix}${var.grafana_namespace}", service = "grafana", port = 80, tls = "grafana-tls", group = "system" }
    harbor     = { host = "harbor.${var.base_domain}", namespace = "${var.ns_prefix}${var.harbor_namespace}", service = "harbor", port = 80, tls = "harbor-tls", group = "apps" }
    velero     = { host = "velero.${var.base_domain}", namespace = "${var.ns_prefix}velero", service = "velero", port = 8085, tls = "velero-tls", group = "system" }
    gitea      = { host = "gitea.${var.base_domain}", namespace = "${var.ns_prefix}gitea", service = "gitea-http", port = 3000, tls = "gitea-tls", group = "apps" }
    mattermost = { host = "mattermost.${var.base_domain}", namespace = "${var.ns_prefix}mattermost", service = "mattermost-team-edition", port = 8065, tls = "mattermost-tls", group = "apps" }
    # qdrant lives in disabled/; its route would fail without the namespace:
    # qdrant    = { host = "qdrant.${var.base_domain}", namespace = "qdrant", service = "qdrant", port = 6333, tls = "qdrant-tls", group = "apps" }
    headlamp = { host = "headlamp.${var.base_domain}", namespace = "${var.ns_prefix}headlamp", service = "headlamp", port = 80, tls = "headlamp-tls", group = "system" }
  })

  # Axigen WebMail: only once system/axigen.tf is enabled (it needs a license).
  axigen_vhost = local.axigen_enabled ? {
    mail = { host = "mail.${var.base_domain}", namespace = local.axigen_namespace, service = "axigen-mail-wm-fe-svc", port = 80, tls = "mail-tls", group = "apps" }
  } : {}

  # Per-host HTTPS listeners for each Gateway, rendered with explicit absolute
  # indentation so the block drops straight into its manifest under `listeners:`.
  gw_https_listeners = { for gw, hosts in { private = local.vhosts, public = local.public_vhosts } :
    gw => join("\n", [for k, v in hosts : join("\n", [
      "    - name: https-${k}",
      "      protocol: HTTPS",
      "      port: 443",
      "      hostname: ${v.host}",
      "      allowedRoutes:",
      "        namespaces:",
      "          from: All",
      "      tls:",
      "        mode: Terminate",
      "        certificateRefs:",
      "          - kind: Secret",
      "            name: ${v.tls}",
    ])])
  }
}

resource "helm_release" "envoy_gateway" {
  name             = "envoy-gateway"
  repository       = "oci://docker.io/envoyproxy"
  chart            = "gateway-helm"
  namespace        = "envoy-gateway-system"
  create_namespace = true
  version          = "v1.10.0"
}

resource "kubernetes_namespace" "gateway" {
  metadata {
    name = local.gateway_namespace
  }
}

resource "kubectl_manifest" "gatewayclass" {
  yaml_body  = <<-EOF
    apiVersion: gateway.networking.k8s.io/v1
    kind: GatewayClass
    metadata:
      name: eg
    spec:
      controllerName: gateway.envoyproxy.io/gatewayclass-controller
  EOF
  depends_on = [helm_release.envoy_gateway]
}

resource "kubectl_manifest" "gateway" {
  yaml_body = <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: aviary
  namespace: ${local.gateway_namespace}
  annotations:
    cert-manager.io/cluster-issuer: ${var.cluster_issuer}
spec:
  gatewayClassName: eg
  listeners:
    - name: http
      protocol: HTTP
      port: 80
      allowedRoutes:
        namespaces:
          from: All
${local.gw_https_listeners.private}
${local.gw_dns_listeners}
EOF
  depends_on = [
    kubectl_manifest.gatewayclass,
    kubernetes_namespace.gateway,
  ]
}

# A second Gateway with the same listeners on its own load-balancer address
# (var.nat_gateway_ip, which must be in the cluster's Cilium LB pool), so a
# router can NAT outside traffic to it without touching the internal one.
# No HTTPRoute is attached to it here: the landing page's public switch does
# that, app by app (see kubectl_manifest.httproute). Serving the private hostnames, it carries
# no cert-manager annotation: it reuses the <app>-tls Secrets the first Gateway
# already has issued, and two annotated Gateways would fight over the same
# Certificates. With public_domain set its hostnames and Secrets are its own
# (<app>-public-tls), so it is annotated with public_cluster_issuer.
resource "kubectl_manifest" "gateway_nat" {
  count     = local.nat_gateway_enabled ? 1 : 0
  yaml_body = <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: ${local.nat_gateway_name}
  namespace: ${local.gateway_namespace}
%{if local.public_domain_enabled~}
  annotations:
    cert-manager.io/cluster-issuer: ${local.public_cluster_issuer}
%{endif~}
spec:
  gatewayClassName: eg
  infrastructure:
    annotations:
      lbipam.cilium.io/ips: "${var.nat_gateway_ip}"
  listeners:
    - name: http
      protocol: HTTP
      port: 80
      allowedRoutes:
        namespaces:
          from: All
${local.gw_https_listeners.public}
${local.gw_dns_listeners}
EOF
  depends_on = [
    kubectl_manifest.gateway,
    kubectl_manifest.letsencrypt,
  ]
}

# Let's Encrypt, for the public_domain certificates. HTTP-01 through the public
# Gateway's port-80 listener, so Let's Encrypt must be able to reach
# http://<app>.<public_domain>/ there: public DNS for the names, and ports 80
# and 443 NATed to nat_gateway_ip. cert-manager also checks each challenge
# itself first, so the same URL has to work from inside the cluster. No contact
# email is registered (ACME does not require one).
resource "kubectl_manifest" "letsencrypt" {
  count     = local.letsencrypt_enabled ? 1 : 0
  yaml_body = <<-EOF
    apiVersion: cert-manager.io/v1
    kind: ClusterIssuer
    metadata:
      name: letsencrypt
    spec:
      acme:
        server: https://acme-v02.api.letsencrypt.org/directory
        privateKeySecretRef:
          name: letsencrypt-account-key
        solvers:
          - http01:
              gatewayHTTPRoute:
                parentRefs:
                  - group: gateway.networking.k8s.io
                    kind: Gateway
                    name: ${local.nat_gateway_name}
                    namespace: ${local.gateway_namespace}
                    sectionName: http
  EOF
}

# Redirect all plaintext HTTP to HTTPS (parity with the old force-ssl-redirect).
resource "kubectl_manifest" "https_redirect" {
  yaml_body  = <<-EOF
    apiVersion: gateway.networking.k8s.io/v1
    kind: HTTPRoute
    metadata:
      name: https-redirect
      namespace: ${local.gateway_namespace}
    spec:
      parentRefs:
        - name: aviary
          sectionName: http
    %{if local.nat_gateway_enabled}
        - name: ${local.nat_gateway_name}
          sectionName: http
    %{endif}
      rules:
        - filters:
            - type: RequestRedirect
              requestRedirect:
                scheme: https
                statusCode: 301
  EOF
  depends_on = [kubectl_manifest.gateway, kubectl_manifest.gateway_nat]
}

# One HTTPRoute per vhost, created in the backend's namespace (so backendRefs
# stay same-namespace and need no ReferenceGrant) and attached to the shared
# Gateway's matching HTTPS listener.
resource "kubectl_manifest" "httproute" {
  for_each = local.vhosts

  yaml_body = <<-EOF
    apiVersion: gateway.networking.k8s.io/v1
    kind: HTTPRoute
    metadata:
      name: ${each.key}
      namespace: ${each.value.namespace}
      labels:
        aviary/group: ${each.value.group}
    spec:
      parentRefs:
        - name: aviary
          namespace: ${local.gateway_namespace}
          sectionName: https-${each.key}
      hostnames:
        - ${each.value.host}
    %{if local.public_domain_enabled}
        - ${local.public_vhosts[each.key].host}
    %{endif}
      rules:
        - backendRefs:
            - name: ${each.value.service}
              port: ${each.value.port}
    %{if each.key == "aviary"}
          # The landing page's chat window streams model replies, and the first
          # one after a cold start waits for the model to load onto the GPU:
          # well past Envoy's 15s default.
          timeouts:
            request: 300s
    %{endif}
  EOF

  # Every route starts on the private Gateway only. Going public is a decision
  # made per app with the landing page's exposure switches, which add and
  # remove parentRefs (private = aviary, public = aviary-nat); system entries
  # have no switch and so stay private. After create the switches own the
  # field, so a later apply does not undo them. (Any other change to a route
  # re-applies the whole manifest and puts it back on the private Gateway only.)
  ignore_fields = ["spec.parentRefs"]

  # Requires the Gateway (CRDs + listener) and the backend namespace to exist.
  # Only same-stack releases are ordered here; apps in the apps/ stack
  # (argo, drone, rustpad, bash) are applied separately, so their
  # namespaces must already exist when this runs.
  depends_on = [
    kubectl_manifest.gateway,
    kubectl_manifest.gateway_nat,
    helm_release.harbor,
    helm_release.velero,
    helm_release.headlamp,
    helm_release.gitea,
    helm_release.mattermost,
    helm_release.axigen,
  ]
}

# Stable-named alias Service that selects this Gateway's Envoy proxy pods, giving
# in-cluster ExternalName aliases (gitea, drone) a predictable target now that
# ingress-nginx-controller is gone. The proxy pods live in the controller
# namespace (envoy-gateway-system) and carry owning-gateway labels.
resource "kubectl_manifest" "gateway_alias_svc" {
  yaml_body  = <<-EOF
    apiVersion: v1
    kind: Service
    metadata:
      name: aviary-gateway
      namespace: envoy-gateway-system
    spec:
      selector:
        gateway.envoyproxy.io/owning-gateway-name: aviary
        gateway.envoyproxy.io/owning-gateway-namespace: ${local.gateway_namespace}
      ports:
        - name: https
          port: 443
          targetPort: 443
        - name: http
          port: 80
          targetPort: 80
  EOF
  depends_on = [kubectl_manifest.gateway]
}
