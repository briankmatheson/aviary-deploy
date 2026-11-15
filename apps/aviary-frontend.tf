# Aviary landing page (github.com/briankmatheson/aviary-frontend): a menu
# built from the cluster's HTTPRoutes, the CA at /ca.crt, a node table.
# Served at https://<base_domain>/ by the shared Envoy Gateway.

resource "kubernetes_namespace" "aviary" {
  metadata {
    name = "aviary"
  }
}

resource "kubernetes_service_account" "aviary_frontend" {
  metadata {
    name      = "aviary-frontend"
    namespace = kubernetes_namespace.aviary.metadata[0].name
  }
}

# Read-only: routes/gateways for the menu, nodes for the table, the
# ClusterIssuer to find the CA secret, metrics if metrics-server is there.
resource "kubernetes_cluster_role" "aviary_frontend" {
  metadata {
    name = "aviary-frontend"
  }
  rule {
    api_groups = ["gateway.networking.k8s.io"]
    resources  = ["httproutes", "gateways"]
    verbs      = ["get", "list", "watch"]
  }
  rule {
    api_groups = [""]
    resources  = ["nodes"]
    verbs      = ["get", "list", "watch"]
  }
  rule {
    api_groups = ["cert-manager.io"]
    resources  = ["clusterissuers"]
    verbs      = ["get", "list"]
  }
  rule {
    api_groups = ["metrics.k8s.io"]
    resources  = ["nodes"]
    verbs      = ["get", "list"]
  }
}

resource "kubernetes_cluster_role_binding" "aviary_frontend" {
  metadata {
    name = "aviary-frontend"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.aviary_frontend.metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.aviary_frontend.metadata[0].name
    namespace = kubernetes_namespace.aviary.metadata[0].name
  }
}

# Only the issuer's CA secret, not every secret in cert-manager's namespace.
# An ACME issuer carries its root in spec.acme.caBundle instead; no secret.
locals {
  issuer_ca_secret = try(data.kubernetes_resource.cluster_issuer.object.spec.ca.secretName, null)
}

resource "kubernetes_role" "aviary_frontend_ca" {
  count = local.issuer_ca_secret == null ? 0 : 1
  metadata {
    name      = "aviary-frontend-ca"
    namespace = "cert-manager"
  }
  rule {
    api_groups     = [""]
    resources      = ["secrets"]
    resource_names = [local.issuer_ca_secret]
    verbs          = ["get"]
  }
}

data "kubernetes_resource" "cluster_issuer" {
  api_version = "cert-manager.io/v1"
  kind        = "ClusterIssuer"
  metadata {
    name = var.cluster_issuer
  }
}

resource "kubernetes_role_binding" "aviary_frontend_ca" {
  count = local.issuer_ca_secret == null ? 0 : 1
  metadata {
    name      = "aviary-frontend-ca"
    namespace = "cert-manager"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.aviary_frontend_ca[0].metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.aviary_frontend.metadata[0].name
    namespace = kubernetes_namespace.aviary.metadata[0].name
  }
}

# kubectl_manifest rather than kubernetes_deployment: hashicorp/kubernetes
# 2.38 + tofu 1.13 trips "Unexpected Identity Change" on re-read of the latter.
resource "kubectl_manifest" "aviary_frontend" {
  yaml_body  = <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: aviary-frontend
  namespace: ${kubernetes_namespace.aviary.metadata[0].name}
  labels:
    app: aviary-frontend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: aviary-frontend
  template:
    metadata:
      labels:
        app: aviary-frontend
    spec:
      serviceAccountName: ${kubernetes_service_account.aviary_frontend.metadata[0].name}
      containers:
        - name: aviary-frontend
          image: ${var.aviary_frontend_image}
          ports:
            - containerPort: 8086
          env:
            - name: BASE_DOMAIN
              value: ${var.base_domain}
            - name: CLUSTER_ISSUER
              value: ${var.cluster_issuer}
          readinessProbe:
            httpGet:
              path: /healthz
              port: 8086
          resources:
            requests:
              cpu: 20m
              memory: 64Mi
            limits:
              memory: 256Mi
EOF
  depends_on = [kubernetes_cluster_role_binding.aviary_frontend, kubernetes_role_binding.aviary_frontend_ca]
}

resource "kubernetes_service" "aviary_frontend" {
  metadata {
    name      = "aviary-frontend"
    namespace = kubernetes_namespace.aviary.metadata[0].name
    labels    = { app = "aviary-frontend" }
  }
  spec {
    selector = { app = "aviary-frontend" }
    port {
      port        = 8086
      target_port = 8086
    }
  }
}
# Exposure handled by the shared Envoy Gateway (<base_domain> -> aviary/aviary-frontend:8086).

# Stopping/starting apps from the landing page runs helm uninstall/install as
# this ServiceAccount, so it must be able to delete and create any resource an
# app chart contains -- i.e. cluster-admin. The page has no auth of its own, so
# anyone who can reach it can stop/start apps. That is acceptable on the homelab
# mesh behind the gateway; gate the buttons (or the page) before exposing it.
resource "kubernetes_cluster_role_binding" "aviary_frontend_admin" {
  metadata {
    name = "aviary-frontend-admin"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.aviary_frontend.metadata[0].name
    namespace = kubernetes_namespace.aviary.metadata[0].name
  }
}
