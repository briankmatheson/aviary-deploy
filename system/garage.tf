# Garage: S3-compatible object storage on the cluster's own disks (three nodes,
# three copies of everything), for backups and whatever else wants a bucket.
# In-cluster S3 endpoint: http://garage.<ns_prefix>garage.svc:3900, region
# "garage", path-style addressing.
#
# The chart is not published in a chart repository: system/charts/garage is a
# copy of script/helm/garage from Garage v2.5.0 (git.deuxfleurs.fr/Deuxfleurs/garage).
#
# Garage has no web page of its own. garage.<base_domain> is Garage Web UI
# (khairul169/garage-webui) on top of the admin API: no login of its own, so
# it sits behind the admins-only Gitea gate and only the gateway reaches it.
#
# Inert until garage_admin_token is set (the admin API's bearer token).
#
# NOT done by this file -- once, after the first install, give the nodes their
# role or Garage stores nothing:
#   garage status                                  # the three node ids
#   garage layout assign -z <zone> -c <size>G <id> # for each
#   garage layout apply --version 1
# Buckets and keys are made with the CLI or the web UI.

locals {
  garage_enabled   = var.garage_admin_token != ""
  garage_namespace = "${var.ns_prefix}garage"
}

resource "kubernetes_namespace" "garage" {
  count = local.garage_enabled ? 1 : 0
  metadata {
    name = local.garage_namespace
  }
}

resource "kubernetes_secret" "garage_admin" {
  count = local.garage_enabled ? 1 : 0
  metadata {
    name      = "garage-admin"
    namespace = kubernetes_namespace.garage[0].metadata[0].name
  }
  data = {
    "admin-token" = var.garage_admin_token
  }
}

resource "helm_release" "garage" {
  count     = local.garage_enabled ? 1 : 0
  name      = "garage"
  chart     = "${path.module}/charts/garage"
  namespace = kubernetes_namespace.garage[0].metadata[0].name
  timeout   = 600

  values = [yamlencode({
    deployment = { replicaCount = 3 }
    garage = {
      replicationFactor = "3"
      s3 = {
        api = { region = "garage", rootDomain = ".s3.${var.base_domain}" }
        web = { rootDomain = ".web.${var.base_domain}" }
      }
    }
    persistence = {
      meta = { size = "1Gi" }
      data = { size = "${var.garage_data_size}Gi" }
    }
    # The admin API as a Service, for the web UI.
    service = { admin = { enabled = true } }
    environment = [{
      name      = "GARAGE_ADMIN_TOKEN"
      valueFrom = { secretKeyRef = { name = kubernetes_secret.garage_admin[0].metadata[0].name, key = "admin-token" } }
    }]
  })]
}

resource "kubectl_manifest" "garage_webui" {
  count      = local.garage_enabled ? 1 : 0
  yaml_body  = <<EOF
# Garage Web UI (khairul169/garage-webui): buckets, keys, layout and an object
# browser on top of Garage's admin API. It has no login of its own here: the
# admins-only gate at the gateway is the door, and only the gateway reaches it.
apiVersion: apps/v1
kind: Deployment
metadata: {name: garage-webui, namespace: ${kubernetes_namespace.garage[0].metadata[0].name}, labels: {app: garage-webui}}
spec:
  replicas: 1
  selector: {matchLabels: {app: garage-webui}}
  template:
    metadata: {labels: {app: garage-webui}}
    spec:
      containers:
      - name: webui
        image: khairul169/garage-webui:1.1.0
        ports: [{containerPort: 3909}]
        env:
        - {name: API_BASE_URL, value: "http://garage-admin.${local.garage_namespace}.svc.cluster.local:3903"}
        - {name: S3_ENDPOINT_URL, value: "http://garage.${local.garage_namespace}.svc.cluster.local:3900"}
        - {name: S3_REGION, value: garage}
        - name: API_ADMIN_KEY
          valueFrom: {secretKeyRef: {name: garage-admin, key: admin-token}}
        readinessProbe: {tcpSocket: {port: 3909}}
        resources: {requests: {cpu: 10m, memory: 32Mi}, limits: {memory: 256Mi}}
EOF
  depends_on = [helm_release.garage]
}

resource "kubectl_manifest" "garage_webui_service" {
  count      = local.garage_enabled ? 1 : 0
  yaml_body  = <<EOF
apiVersion: v1
kind: Service
metadata: {name: garage-webui, namespace: ${kubernetes_namespace.garage[0].metadata[0].name}}
spec:
  selector: {app: garage-webui}
  ports: [{port: 3909, targetPort: 3909}]
EOF
  depends_on = [helm_release.garage]
}

resource "kubectl_manifest" "garage_webui_gateway_only" {
  count      = local.garage_enabled ? 1 : 0
  yaml_body  = <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: webui-gateway-only, namespace: ${kubernetes_namespace.garage[0].metadata[0].name}}
spec:
  podSelector: {matchLabels: {app: garage-webui}}
  policyTypes: [Ingress]
  ingress:
  - from: [{namespaceSelector: {matchLabels: {kubernetes.io/metadata.name: envoy-gateway-system}}}]
    ports: [{port: 3909}]
EOF
  depends_on = [helm_release.garage]
}
# Exposure handled by the shared Envoy Gateway (garage.<base_domain> -> garage-webui:3909).
