# CloudBeaver: DBeaver's database client as a web page (cloudbeaver.<base_domain>,
# via the shared Envoy Gateway). There is no official chart: the upstream image,
# a volume for its workspace (connections, users, settings) and a Service.
#
# No database connections are set up: people add their own. It can reach
# anything the cluster network can, so it stays behind the Gitea login.
#
# Sign-in is by Gitea: the gateway's gate checks Gitea's ID token and passes
# its preferred_username to CloudBeaver as X-User (CloudBeaver's reverse-proxy
# authentication; the gate also pins X-Team to "user"). Two things about that
# are NOT done by this file:
#   - the gate itself (SecurityPolicy gitea-login-cloudbeaver) is applied by
#     hand, like the other gates;
#   - reverse-proxy authentication is switched on in CloudBeaver's runtime
#     configuration on the volume (.data/.cloudbeaver.runtime.conf:
#     app.enableReverseProxyAuth true, "reverseProxy" in enabledAuthProviders),
#     which has no environment variable.
# Because CloudBeaver believes X-User from whoever reaches it, the
# NetworkPolicy below lets only the gateway's proxies in.
#
# Left to itself the first visitor is walked through a setup wizard and picks
# the administrator's password. CB_ADMIN_* configure the server at first start
# instead, so the whole file is inert until cloudbeaver_admin_password is set.

locals {
  cloudbeaver_enabled   = var.cloudbeaver_admin_password != ""
  cloudbeaver_namespace = "${var.ns_prefix}cloudbeaver"
}

resource "kubernetes_namespace" "cloudbeaver" {
  count = local.cloudbeaver_enabled ? 1 : 0
  metadata {
    name = local.cloudbeaver_namespace
  }
}

resource "kubernetes_secret" "cloudbeaver_admin" {
  count = local.cloudbeaver_enabled ? 1 : 0
  metadata {
    name      = "cloudbeaver-admin"
    namespace = kubernetes_namespace.cloudbeaver[0].metadata[0].name
  }
  data = {
    username = var.cloudbeaver_admin_user
    password = var.cloudbeaver_admin_password
  }
}

resource "kubernetes_persistent_volume_claim" "cloudbeaver" {
  count = local.cloudbeaver_enabled ? 1 : 0
  metadata {
    name      = "cloudbeaver-workspace"
    namespace = kubernetes_namespace.cloudbeaver[0].metadata[0].name
  }
  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = var.global_storage_class
    resources {
      requests = {
        storage = "${var.cloudbeaver_pvc_size}Gi"
      }
    }
  }
  wait_until_bound = false
}

# kubectl_manifest rather than kubernetes_deployment, as in rustpad.tf.
resource "kubectl_manifest" "cloudbeaver" {
  count     = local.cloudbeaver_enabled ? 1 : 0
  yaml_body = <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cloudbeaver
  namespace: ${kubernetes_namespace.cloudbeaver[0].metadata[0].name}
  labels:
    app: cloudbeaver
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: cloudbeaver
  template:
    metadata:
      labels:
        app: cloudbeaver
    spec:
      containers:
        - name: cloudbeaver
          image: dbeaver/cloudbeaver:${var.cloudbeaver_version}
          ports:
            - containerPort: 8978
          env:
            - name: CB_SERVER_NAME
              value: CloudBeaver
            - name: CB_SERVER_URL
              value: https://cloudbeaver.${var.base_domain}
            # Nobody uses it without an account of its own (the admin makes them).
            - name: CLOUDBEAVER_APP_ANONYMOUS_ACCESS_ENABLED
              value: "false"
            # People add connections of their own (none are set up for them).
            - name: CLOUDBEAVER_APP_SUPPORTS_CUSTOM_CONNECTIONS
              value: "true"
            - name: CB_ADMIN_NAME
              valueFrom:
                secretKeyRef:
                  name: ${kubernetes_secret.cloudbeaver_admin[0].metadata[0].name}
                  key: username
            - name: CB_ADMIN_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: ${kubernetes_secret.cloudbeaver_admin[0].metadata[0].name}
                  key: password
          readinessProbe:
            httpGet:
              path: /
              port: 8978
          resources:
            requests:
              cpu: 50m
              memory: 512Mi
            limits:
              memory: 2Gi
          volumeMounts:
            - name: workspace
              mountPath: /opt/cloudbeaver/workspace
      volumes:
        - name: workspace
          persistentVolumeClaim:
            claimName: ${kubernetes_persistent_volume_claim.cloudbeaver[0].metadata[0].name}
EOF
}

resource "kubernetes_service" "cloudbeaver" {
  count = local.cloudbeaver_enabled ? 1 : 0
  metadata {
    name      = "cloudbeaver"
    namespace = kubernetes_namespace.cloudbeaver[0].metadata[0].name
  }
  spec {
    selector = { app = "cloudbeaver" }
    port {
      port        = 8978
      target_port = 8978
    }
  }
}

resource "kubectl_manifest" "cloudbeaver_gateway_only" {
  count     = local.cloudbeaver_enabled ? 1 : 0
  yaml_body = <<-EOF
    apiVersion: networking.k8s.io/v1
    kind: NetworkPolicy
    metadata:
      name: gateway-only
      namespace: ${kubernetes_namespace.cloudbeaver[0].metadata[0].name}
    spec:
      podSelector:
        matchLabels:
          app: cloudbeaver
      policyTypes:
        - Ingress
      ingress:
        - from:
            - namespaceSelector:
                matchLabels:
                  kubernetes.io/metadata.name: envoy-gateway-system
          ports:
            - port: 8978
  EOF
}
# Exposure handled by the shared Envoy Gateway (cloudbeaver.<base_domain> -> cloudbeaver:8978).
