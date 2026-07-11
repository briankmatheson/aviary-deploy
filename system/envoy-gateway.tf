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

  # host -> backend Service routing table. One HTTPS listener and one HTTPRoute
  # are generated per entry. `namespace`/`service`/`port` identify the backend.
  vhosts = {
    argo        = { host = "argo.local", namespace = "argo", service = "argo-server", port = 80, tls = "argo-tls" }
    aviary      = { host = "aviary.local", namespace = "kube-system", service = "aviary", port = 8086, tls = "aviary-tls" }
    bash        = { host = "bash.local", namespace = "default", service = "cloudshell-aviary-bash", port = 7681, tls = "bash-tls" }
    drone       = { host = "drone.local", namespace = "drone", service = "drone", port = 80, tls = "drone-tls" }
    rustpad     = { host = "rustpad.local", namespace = "rustpad", service = "rustpad", port = 3030, tls = "rustpad-tls" }
    grafana     = { host = "grafana.local", namespace = "grafana", service = "grafana", port = 80, tls = "grafana-tls" }
    harbor      = { host = "harbor.local", namespace = "harbor", service = "harbor", port = 80, tls = "harbor-tls" }
    velero      = { host = "velero.local", namespace = "velero", service = "velero", port = 8085, tls = "velero-tls" }
    gitea       = { host = "gitea.local", namespace = "gitea", service = "gitea-http", port = 3000, tls = "gitea-tls" }
    postgres-ui = { host = "postgres-ui.local", namespace = "zalando-postgres", service = "postgres-ui-postgres-operator-ui", port = 80, tls = "postgres-ui-tls" }
    qdrant      = { host = "qdrant.local", namespace = "qdrant", service = "qdrant", port = 6333, tls = "qdrant-tls" }
    headlamp    = { host = "headlamp.local", namespace = "headlamp", service = "headlamp", port = 80, tls = "headlamp-tls" }
  }

  # Per-host HTTPS listeners, rendered with explicit absolute indentation so the
  # block drops straight into the Gateway manifest under `listeners:`.
  gw_https_listeners = join("\n", [for k, v in local.vhosts : join("\n", [
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

resource "helm_release" "envoy_gateway" {
  name             = "envoy-gateway"
  repository       = "oci://docker.io/envoyproxy"
  chart            = "gateway-helm"
  namespace        = "envoy-gateway-system"
  create_namespace = true
  # Pin to a known-good release before promoting past wip.
  # version = "v1.2.1"
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
${local.gw_https_listeners}
EOF
  depends_on = [
    kubectl_manifest.gatewayclass,
    kubernetes_namespace.gateway,
  ]
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
      rules:
        - filters:
            - type: RequestRedirect
              requestRedirect:
                scheme: https
                statusCode: 301
  EOF
  depends_on = [kubectl_manifest.gateway]
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
    spec:
      parentRefs:
        - name: aviary
          namespace: ${local.gateway_namespace}
          sectionName: https-${each.key}
      hostnames:
        - ${each.value.host}
      rules:
        - backendRefs:
            - name: ${each.value.service}
              port: ${each.value.port}
  EOF

  # Requires the Gateway (CRDs + listener) and the backend namespace to exist.
  # Only same-stack releases are ordered here; apps in the apps/ and data/
  # stacks (argo, drone, rustpad, bash, gitea, zalando_postgres, qdrant) are
  # applied separately, so their namespaces must already exist when this runs.
  depends_on = [
    kubectl_manifest.gateway,
    helm_release.grafana,
    helm_release.harbor,
    helm_release.velero,
    helm_release.headlamp,
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
