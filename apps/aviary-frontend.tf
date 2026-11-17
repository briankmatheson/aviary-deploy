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

# What the landing page may do. It is deliberately not cluster-admin (it was,
# while stop/start ran helm): three roles, each as narrow as its job.
#
#   aviary-frontend        cluster-wide: read what the page shows, and the few
#                          cluster-scoped changes it makes (delete a dead node
#                          and what it left behind; its own settings' status)
#   aviary-frontend-app    the controls on a tile, bound only in the namespaces
#                          of the apps the page lists (local.aviary_app_namespaces)
#   aviary-frontend-self   its own namespace: its ConfigMaps, the API-key
#                          Secret, tokens for the whiteboard's read-only account
#
# It reads no Secret but the registry pull secret (to list an image's tags)
# and its own API key, creates no pods and no RBAC, and cannot touch a
# workload outside the listed namespaces. A new app's namespace has to be
# added to the list for its tile's controls to work.
resource "kubernetes_cluster_role" "aviary_frontend" {
  metadata {
    name = "aviary-frontend"
  }
  rule {
    api_groups = [""]
    resources  = ["nodes", "namespaces", "pods", "persistentvolumeclaims", "persistentvolumes", "limitranges"]
    verbs      = ["get", "list", "watch"]
  }
  rule {
    api_groups = [""]
    resources  = ["nodes", "pods"]
    verbs      = ["delete"]
  }
  rule {
    api_groups = ["apps"]
    resources  = ["deployments", "statefulsets", "daemonsets", "deployments/scale", "statefulsets/scale"]
    verbs      = ["get", "list", "watch"]
  }
  rule {
    api_groups = ["storage.k8s.io"]
    resources  = ["volumeattachments"]
    verbs      = ["get", "list", "delete"]
  }
  rule {
    api_groups = ["gateway.networking.k8s.io"]
    resources  = ["gateways", "httproutes", "tcproutes", "udproutes"]
    verbs      = ["get", "list", "watch"]
  }
  rule {
    api_groups = ["cert-manager.io"]
    resources  = ["clusterissuers"]
    verbs      = ["get", "list"]
  }
  rule {
    api_groups = ["metrics.k8s.io"]
    resources  = ["nodes", "pods"]
    verbs      = ["get", "list"]
  }
  rule {
    api_groups = ["aviary.xdebbie.org"]
    resources  = ["aviaryapps", "aviaryconfigs"]
    verbs      = ["get", "list", "watch"]
  }
  rule {
    api_groups = ["aviary.xdebbie.org"]
    resources  = ["aviaryconfigs/status"]
    verbs      = ["get", "patch", "update"]
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
          # The image is usually a moving tag (:latest), rolled out by restarting:
          # without this a node reuses whichever :latest it pulled last, however old.
          imagePullPolicy: Always
          ports:
            - containerPort: 8086
          env:
            - name: BASE_DOMAIN
              value: ${var.base_domain}
            - name: CLUSTER_ISSUER
              value: ${var.cluster_issuer}
            - name: BASE_URL
              value: https://${var.base_domain}
            - name: OAUTH_ISSUER
              value: https://gitea.${var.base_domain}
            - name: GITEA_INTERNAL
              value: http://gitea-http.${var.ns_prefix}gitea.svc.cluster.local:3000
            - name: OAUTH_ADMIN_ONLY
              value: "${var.aviary_oauth_admin_only}"
            - name: CHAT_URL
              value: "${local.aviary_chat_url}"
            - name: CHAT_MODEL
              value: "${var.aviary_chat_model}"
            - name: OAUTH_CLIENT_ID
              valueFrom:
                secretKeyRef:
                  name: aviary-frontend-oauth
                  key: client_id
            - name: OAUTH_CLIENT_SECRET
              valueFrom:
                secretKeyRef:
                  name: aviary-frontend-oauth
                  key: client_secret
            - name: SESSION_SECRET
              valueFrom:
                secretKeyRef:
                  name: aviary-frontend-oauth
                  key: session_secret
            - name: BYPASS_TOKEN
              valueFrom:
                secretKeyRef:
                  name: aviary-frontend-oauth
                  key: bypass_token
            # Claude in the whiteboard: there only when the key is set (the
            # page treats an empty value as no key).
            - name: ANTHROPIC_API_KEY
              valueFrom:
                secretKeyRef:
                  name: aviary-frontend-oauth
                  key: anthropic_api_key
            - name: CLAUDE_MODEL
              value: "${var.aviary_claude_model}"
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
  depends_on = [kubernetes_cluster_role_binding.aviary_frontend, kubernetes_role_binding.aviary_frontend_ca, kubernetes_secret.aviary_frontend_oauth]
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

locals {
  # Namespaces whose apps the page's controls reach: every app with a tile,
  # the extra namespaces a tile counts (Drone's builds), the model server
  # the whiteboard's menu starts and stops, and "default" (the shell).
  aviary_app_namespaces = concat(
    [for a in [
      "argo", "axigen", "cloudbeaver", "cnpg-ui", "dns", "drone", "drone-builds", "garage", "gitea", "grafana",
      "harbor", "headlamp", "jitsi", "kubeshark", "mattermost", "ollama", "rustpad", "velero",
    ] : "${var.ns_prefix}${a}"],
    [kubernetes_namespace.aviary.metadata[0].name, "default"],
  )
}

resource "kubernetes_cluster_role" "aviary_frontend_app" {
  metadata {
    name = "aviary-frontend-app"
  }
  rule {
    api_groups = ["apps"]
    resources  = ["deployments", "statefulsets", "daemonsets"]
    verbs      = ["patch", "update"]
  }
  rule {
    api_groups = ["apps"]
    resources  = ["deployments/scale", "statefulsets/scale"]
    verbs      = ["get", "patch", "update"]
  }
  rule {
    api_groups = [""]
    resources  = ["limitranges"]
    verbs      = ["get", "create", "update", "patch"]
  }
  rule {
    api_groups = ["gateway.networking.k8s.io"]
    resources  = ["httproutes", "tcproutes", "udproutes"]
    verbs      = ["get", "update", "patch"]
  }
  rule {
    api_groups     = [""]
    resources      = ["secrets"]
    resource_names = ["mesh-reg"]
    verbs          = ["get"]
  }
}

# Only where the namespace exists: an app that is not installed has none.
data "kubernetes_all_namespaces" "all" {}

resource "kubernetes_role_binding" "aviary_frontend_app" {
  for_each = toset([for n in local.aviary_app_namespaces : n if contains(data.kubernetes_all_namespaces.all.namespaces, n)])
  metadata {
    name      = "aviary-frontend-app"
    namespace = each.key
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.aviary_frontend_app.metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.aviary_frontend.metadata[0].name
    namespace = kubernetes_namespace.aviary.metadata[0].name
  }
}

# The gateway's own namespace holds routes the page switches and nothing of
# an app's: there it may edit routes, and no workload.
resource "kubernetes_cluster_role" "aviary_frontend_routes" {
  metadata {
    name = "aviary-frontend-routes"
  }
  rule {
    api_groups = ["gateway.networking.k8s.io"]
    resources  = ["httproutes", "tcproutes", "udproutes"]
    verbs      = ["get", "update", "patch"]
  }
}

resource "kubernetes_role_binding" "aviary_frontend_routes" {
  metadata {
    name      = "aviary-frontend-routes"
    namespace = var.gateway_namespace
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.aviary_frontend_routes.metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.aviary_frontend.metadata[0].name
    namespace = kubernetes_namespace.aviary.metadata[0].name
  }
}

resource "kubernetes_role" "aviary_frontend_self" {
  metadata {
    name      = "aviary-frontend-self"
    namespace = kubernetes_namespace.aviary.metadata[0].name
  }
  rule {
    api_groups = [""]
    resources  = ["configmaps"]
    verbs      = ["get", "create", "update", "patch"]
  }
  rule {
    api_groups     = [""]
    resources      = ["secrets"]
    resource_names = ["aviary-claude"]
    verbs          = ["get", "update", "delete"]
  }
  # The Gitea token the lock's admin sync uses (made by hand, see
  # by-hand/w10/README.md): read only.
  rule {
    api_groups     = [""]
    resources      = ["secrets"]
    resource_names = ["aviary-gitea-sync"]
    verbs          = ["get"]
  }
  rule {
    api_groups = [""]
    resources  = ["secrets"]
    verbs      = ["create"]
  }
  rule {
    api_groups     = [""]
    resources      = ["serviceaccounts/token"]
    resource_names = ["aviary-chat"]
    verbs          = ["create"]
  }
}

resource "kubernetes_role_binding" "aviary_frontend_self" {
  metadata {
    name      = "aviary-frontend-self"
    namespace = kubernetes_namespace.aviary.metadata[0].name
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.aviary_frontend_self.metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.aviary_frontend.metadata[0].name
    namespace = kubernetes_namespace.aviary.metadata[0].name
  }
}


# OAuth2 client (a gitea application) + session/bypass secrets for the landing
# page's login. Empty values (the variable defaults) leave login disabled.
resource "kubernetes_secret" "aviary_frontend_oauth" {
  metadata {
    name      = "aviary-frontend-oauth"
    namespace = kubernetes_namespace.aviary.metadata[0].name
  }
  data = {
    client_id      = var.aviary_oauth_client_id
    client_secret  = var.aviary_oauth_client_secret
    session_secret = var.aviary_session_secret
    bypass_token   = var.aviary_bypass_token
    # Not OAuth, but the page's other secret: the key Claude answers with.
    anthropic_api_key = var.aviary_anthropic_api_key
  }
}

# The identity the chat room's model reads the cluster with. The page itself can
# change workloads (above); the model's lookups (aviary-frontend's kubernetes_get
# tool) are made with a token for this account instead, so read-only is
# enforced by RBAC and not left to the model. No Secrets: `view` leaves them
# out, and the extra role below does not add them.
resource "kubernetes_service_account" "aviary_chat" {
  metadata {
    name      = "aviary-chat"
    namespace = kubernetes_namespace.aviary.metadata[0].name
  }
}

resource "kubernetes_cluster_role_binding" "aviary_chat_view" {
  metadata {
    name = "aviary-chat-view"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "view"
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.aviary_chat.metadata[0].name
    namespace = kubernetes_namespace.aviary.metadata[0].name
  }
}

# What `view` leaves out that is still worth reading: cluster-scoped objects,
# metrics, and the networking and certificate custom resources.
resource "kubernetes_cluster_role" "aviary_chat_read" {
  metadata {
    name = "aviary-chat-read"
  }
  rule {
    api_groups = [""]
    resources  = ["nodes", "namespaces", "persistentvolumes"]
    verbs      = ["get", "list", "watch"]
  }
  rule {
    api_groups = ["storage.k8s.io"]
    resources  = ["storageclasses", "csinodes", "csidrivers", "volumeattachments"]
    verbs      = ["get", "list", "watch"]
  }
  rule {
    api_groups = ["metrics.k8s.io"]
    resources  = ["nodes", "pods"]
    verbs      = ["get", "list"]
  }
  rule {
    api_groups = ["gateway.networking.k8s.io", "gateway.envoyproxy.io", "cilium.io"]
    resources  = ["*"]
    verbs      = ["get", "list", "watch"]
  }
  rule {
    api_groups = ["cert-manager.io"]
    resources  = ["certificates", "certificaterequests", "issuers", "clusterissuers"]
    verbs      = ["get", "list", "watch"]
  }
  rule {
    api_groups = ["apiextensions.k8s.io"]
    resources  = ["customresourcedefinitions"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_cluster_role_binding" "aviary_chat_read" {
  metadata {
    name = "aviary-chat-read"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.aviary_chat_read.metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.aviary_chat.metadata[0].name
    namespace = kubernetes_namespace.aviary.metadata[0].name
  }
}
