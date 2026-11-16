# Authoritative DNS for the domains in dns_zones: a CoreDNS of its own, apart
# from the cluster's resolver. It answers for those zones and nothing else
# (no recursion: every other name is REFUSED), from the zone files named in
# dns_zones -- edit a file, bump its serial, apply, and the pods pick it up.
#
# It is reached through the Gateways like every app: a UDPRoute and a TCPRoute
# named "dns" on the listeners udp-dns / tcp-dns (port 53). They start on the
# private Gateway only; the landing page's switches attach and detach either
# Gateway (spec.parentRefs is ignored below, as for the HTTPRoutes). Outside
# queries reach the public Gateway through bin/set-nat.sh (DNS_PORTS).
locals {
  dns_enabled   = length(var.dns_zones) > 0
  dns_namespace = "${var.ns_prefix}dns"
  dns_port      = 1053 # unprivileged in the pod; the Service and Gateways serve 53

  dns_corefile = join("\n", concat(
    [for zone in sort(keys(var.dns_zones)) : <<-EOT
      ${zone}:${local.dns_port} {
          file /zones/db.${zone} {
              reload 30s
          }
          prometheus :9153
          errors
      }
      EOT
    ],
    [<<-EOT
      .:${local.dns_port} {
          health :8080
          ready :8181
          prometheus :9153
          errors
          template ANY ANY {
              rcode REFUSED
          }
      }
      EOT
    ]
  ))

  # UDP and TCP 53 on each Gateway, indented to drop in under `listeners:`.
  gw_dns_listeners = local.dns_enabled ? join("\n", [for proto in ["UDP", "TCP"] :
    "    - name: ${lower(proto)}-dns\n      protocol: ${proto}\n      port: 53\n      allowedRoutes:\n        namespaces:\n          from: All"
  ]) : ""
}

resource "kubernetes_namespace" "dns" {
  count = local.dns_enabled ? 1 : 0
  metadata {
    name = local.dns_namespace
  }
}

resource "kubernetes_config_map" "dns" {
  count = local.dns_enabled ? 1 : 0
  metadata {
    name      = "dns"
    namespace = kubernetes_namespace.dns[0].metadata[0].name
  }
  data = merge(
    { Corefile = local.dns_corefile },
    { for zone, path in var.dns_zones : "db.${zone}" => file(path) },
  )
}

resource "kubectl_manifest" "dns" {
  count     = local.dns_enabled ? 1 : 0
  yaml_body = <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dns
  namespace: ${kubernetes_namespace.dns[0].metadata[0].name}
  labels:
    app: dns
spec:
  replicas: ${var.dns_replicas}
  selector:
    matchLabels:
      app: dns
  strategy:
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 1
  template:
    metadata:
      labels:
        app: dns
      annotations:
        # Corefile changes need a restart (zone files reload by themselves).
        aviary/corefile: ${sha256(local.dns_corefile)}
    spec:
      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: kubernetes.io/hostname
          whenUnsatisfiable: ScheduleAnyway
          labelSelector:
            matchLabels:
              app: dns
      securityContext:
        runAsNonRoot: true
        runAsUser: 65532
        runAsGroup: 65532
      containers:
        - name: coredns
          image: ${var.dns_image}
          args: ["-conf", "/zones/Corefile"]
          ports:
            - {name: dns-udp, containerPort: ${local.dns_port}, protocol: UDP}
            - {name: dns-tcp, containerPort: ${local.dns_port}, protocol: TCP}
            - {name: metrics, containerPort: 9153, protocol: TCP}
          resources:
            requests: {cpu: 100m, memory: ${var.dns_memory}}
            limits: {memory: ${var.dns_memory}}
          livenessProbe:
            httpGet: {path: /health, port: 8080}
            initialDelaySeconds: 10
          readinessProbe:
            httpGet: {path: /ready, port: 8181}
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities: {drop: [ALL], add: [NET_BIND_SERVICE]} # the image's binary carries it as a file capability
          volumeMounts:
            - {name: zones, mountPath: /zones, readOnly: true}
      volumes:
        - name: zones
          configMap:
            name: ${kubernetes_config_map.dns[0].metadata[0].name}
EOF
}

resource "kubectl_manifest" "dns_pdb" {
  count     = local.dns_enabled ? 1 : 0
  yaml_body = <<EOF
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: dns
  namespace: ${kubernetes_namespace.dns[0].metadata[0].name}
spec:
  maxUnavailable: 1
  selector:
    matchLabels:
      app: dns
EOF
}

resource "kubernetes_service" "dns" {
  count = local.dns_enabled ? 1 : 0
  metadata {
    name      = "dns"
    namespace = kubernetes_namespace.dns[0].metadata[0].name
  }
  spec {
    selector = { app = "dns" }
    port {
      name        = "dns-udp"
      protocol    = "UDP"
      port        = 53
      target_port = local.dns_port
    }
    port {
      name        = "dns-tcp"
      protocol    = "TCP"
      port        = 53
      target_port = local.dns_port
    }
  }
}

# One route per protocol, both named "dns": the landing page pairs them into
# one row and switches them together.
resource "kubectl_manifest" "dns_route" {
  for_each      = local.dns_enabled ? toset(["UDP", "TCP"]) : toset([])
  ignore_fields = ["spec.parentRefs"]
  yaml_body     = <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: ${each.key}Route
metadata:
  name: dns
  namespace: ${kubernetes_namespace.dns[0].metadata[0].name}
  labels:
    aviary/group: system
spec:
  parentRefs:
    - name: aviary
      namespace: ${local.gateway_namespace}
      sectionName: ${lower(each.key)}-dns
  rules:
    - backendRefs:
        - name: ${kubernetes_service.dns[0].metadata[0].name}
          port: 53
EOF
  depends_on    = [kubectl_manifest.gateway]
}
