# The chart is vendored (apps/charts/drone, upstream 0.6.5 from
# https://charts.drone.io) with two changes to templates/deployment.yaml:
# upstream pins the server to one replica, and breaks on an update strategy
# with more than one key.
#
# With drone_db_password set, the server runs in Drone's HA mode (beta
# upstream): drone_server_replicas pods sharing a Postgres database (a cnpg
# Cluster) and a Redis-compatible store (Valkey) for the build queue, runner
# events, log streaming and cancellations, and no volume of their own.
# Without it: one server on SQLite on a volume, as upstream ships it.
# by-hand/w10/drone-ha has how w10's SQLite data was moved across.
locals {
  drone_ha = var.drone_db_password != ""
}

resource "kubernetes_namespace" "drone" {
  metadata {
    name = "${var.ns_prefix}drone"
  }
}

# cnpg adopts an existing <cluster>-app secret instead of generating one, so
# the password here and in the server's connection string stay the same.
resource "kubernetes_secret" "drone_db" {
  count = local.drone_ha ? 1 : 0
  metadata {
    name      = "drone-pg-app"
    namespace = kubernetes_namespace.drone.metadata[0].name
  }
  type = "kubernetes.io/basic-auth"
  data = {
    username = "drone"
    password = var.drone_db_password
  }
}

resource "kubectl_manifest" "drone_pg" {
  count      = local.drone_ha ? 1 : 0
  yaml_body  = <<-EOF
    apiVersion: postgresql.cnpg.io/v1
    kind: Cluster
    metadata:
      name: drone-pg
      namespace: ${kubernetes_namespace.drone.metadata[0].name}
    spec:
      instances: 1
      storage:
        size: 5Gi
        storageClass: ${var.global_storage_class}
      bootstrap:
        initdb:
          database: drone
          owner: drone
          secret:
            name: ${kubernetes_secret.drone_db[0].metadata[0].name}
      resources:
        requests:
          cpu: 50m
          memory: 256Mi
        limits:
          memory: 512Mi
  EOF
  depends_on = [kubernetes_secret.drone_db]
}

# What every server reads besides the chart's ConfigMap. All servers must
# share the cookie secret, or a login made on one is unknown to the others.
resource "kubernetes_secret" "drone_ha" {
  count = local.drone_ha ? 1 : 0
  metadata {
    name      = "drone-ha"
    namespace = kubernetes_namespace.drone.metadata[0].name
  }
  data = {
    "valkey-password"         = var.drone_valkey_password
    DRONE_COOKIE_SECRET       = var.drone_cookie_secret
    DRONE_DATABASE_DRIVER     = "postgres"
    DRONE_DATABASE_DATASOURCE = "postgres://drone:${var.drone_db_password}@drone-pg-rw.${kubernetes_namespace.drone.metadata[0].name}.svc.cluster.local:5432/drone?sslmode=require"
    DRONE_REDIS_CONNECTION    = "redis://:${var.drone_valkey_password}@drone-valkey.${kubernetes_namespace.drone.metadata[0].name}.svc.cluster.local:6379"
  }
}

# Nothing in it needs to outlive a restart: builds waiting in the queue are
# also in the database.
resource "kubectl_manifest" "drone_valkey" {
  count      = local.drone_ha ? 1 : 0
  yaml_body  = <<-EOF
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: drone-valkey
      namespace: ${kubernetes_namespace.drone.metadata[0].name}
      labels:
        app.kubernetes.io/name: drone-valkey
    spec:
      replicas: 1
      strategy:
        type: Recreate
      selector:
        matchLabels:
          app.kubernetes.io/name: drone-valkey
      template:
        metadata:
          labels:
            app.kubernetes.io/name: drone-valkey
        spec:
          automountServiceAccountToken: false
          securityContext:
            runAsNonRoot: true
            runAsUser: 999
            runAsGroup: 999
            fsGroup: 999
            seccompProfile:
              type: RuntimeDefault
          containers:
            - name: valkey
              image: valkey/valkey:8.1-alpine
              args: ["--requirepass", "$(VALKEY_PASSWORD)", "--save", "", "--appendonly", "no", "--maxmemory", "128mb", "--maxmemory-policy", "noeviction"]
              env:
                - name: VALKEY_PASSWORD
                  valueFrom:
                    secretKeyRef:
                      name: drone-ha
                      key: valkey-password
              ports:
                - containerPort: 6379
              readinessProbe:
                tcpSocket:
                  port: 6379
                periodSeconds: 5
              securityContext:
                allowPrivilegeEscalation: false
                readOnlyRootFilesystem: true
                capabilities:
                  drop: [ALL]
              resources:
                requests:
                  cpu: 10m
                  memory: 32Mi
                limits:
                  memory: 192Mi
              volumeMounts:
                - name: data
                  mountPath: /data
          volumes:
            - name: data
              emptyDir: {}
  EOF
  depends_on = [kubernetes_secret.drone_ha]
}

resource "kubernetes_service" "drone_valkey" {
  count = local.drone_ha ? 1 : 0
  metadata {
    name      = "drone-valkey"
    namespace = kubernetes_namespace.drone.metadata[0].name
  }
  spec {
    selector = { "app.kubernetes.io/name" = "drone-valkey" }
    port {
      port        = 6379
      target_port = 6379
    }
  }
}

resource "helm_release" "drone" {
  name       = "drone"
  chart      = "${path.module}/charts/drone"
  namespace  = kubernetes_namespace.drone.metadata[0].name
  depends_on = [kubectl_manifest.drone_pg, kubectl_manifest.drone_valkey, kubernetes_service.drone_valkey]

  # Ingress disabled; routed via the shared Envoy Gateway (see envoy-gateway.tf).
  # The Gitea OAuth2 client comes from terraform.tfvars (two-phase install,
  # see README). gitea lives in the system/ stack.
  values = concat(
    [yamlencode({
      ingress = { enabled = false }
      env = {
        DRONE_SERVER_HOST         = "drone.${var.base_domain}"
        DRONE_SERVER_PROTO        = "https"
        DRONE_GITEA_SERVER        = "https://gitea.${var.base_domain}"
        DRONE_GITEA_CLIENT_ID     = var.drone_gitea_client_id
        DRONE_GITEA_CLIENT_SECRET = var.drone_gitea_client_secret
        DRONE_RPC_SECRET          = var.drone_rpc_secret
        DRONE_USER_CREATE         = "username:${var.drone_admin_user},machine:false,admin:true"
        # Trust the cluster's internal CA (gitea's cert) via the trust-manager
        # bundle mounted below -- public CAs plus the XDebbie step-ca root.
        SSL_CERT_FILE = "/etc/ssl/certs/ca-bundle.pem"
      }
      extraVolumes = [{
        name      = "ca-bundle"
        configMap = { name = "xdebbie-ca-bundle" }
      }]
      extraVolumeMounts = [{
        name      = "ca-bundle"
        mountPath = "/etc/ssl/certs/ca-bundle.pem"
        subPath   = "ca-bundle.pem"
        readOnly  = true
      }]
    })],
    local.drone_ha ? [yamlencode({
      replicaCount               = var.drone_server_replicas
      updateStrategy             = { type = "RollingUpdate", rollingUpdate = { maxUnavailable = 1, maxSurge = 1 } }
      persistentVolume           = { enabled = false }
      extraSecretNamesForEnvFrom = [kubernetes_secret.drone_ha[0].metadata[0].name]
      affinity = { podAntiAffinity = { preferredDuringSchedulingIgnoredDuringExecution = [{
        weight = 100
        podAffinityTerm = {
          topologyKey   = "kubernetes.io/hostname"
          labelSelector = { matchLabels = { "app.kubernetes.io/name" = "drone", "app.kubernetes.io/component" = "server" } }
        }
      }] } }
      })] : [yamlencode({
      persistentVolume = { storageClass = var.global_storage_class }
      # RWO volume: a RollingUpdate deadlocks on the PVC the old pod holds.
      updateStrategy = { type = "Recreate" }
    })],
  )
}
resource "kubectl_manifest" "gitea" {
  yaml_body = <<EOF
apiVersion: v1
kind: Service
metadata:
  labels:
    app: gitea
  name: gitea
  namespace: ${var.ns_prefix}drone
spec:
  externalName: aviary-gateway.envoy-gateway-system.svc.cluster.local
  selector:
    app: gitea
  sessionAffinity: None
  type: ExternalName
EOF
  # aviary-gateway (kubectl_manifest.gateway_alias_svc) lives in the system/
  # stack; apply system/ so the ExternalName target resolves.
  depends_on = [
    helm_release.drone,
  ]
}
# The runner sits beside the server, and starts each build's pod in a
# namespace of its own: the runner's ServiceAccount can touch pods and secrets
# there and nowhere else, and builds share nothing with other workloads. The
# namespace's aviary/app label makes the landing page count the builds on
# Drone's tile. (Until 2026-11-17 the runner and the builds lived in "default".)
locals {
  drone_namespace        = "${var.ns_prefix}drone"
  drone_builds_namespace = "${var.ns_prefix}drone-builds"
}

resource "kubernetes_namespace" "drone_builds" {
  metadata {
    name   = local.drone_builds_namespace
    labels = { "aviary/app" = "drone" }
  }
}

resource "kubernetes_service_account" "drone_runner" {
  metadata {
    name      = "drone-runner"
    namespace = local.drone_namespace
  }
  depends_on = [helm_release.drone]
}

resource "kubernetes_role" "drone_runner" {
  metadata {
    name      = "drone-runner"
    namespace = kubernetes_namespace.drone_builds.metadata[0].name
  }
  rule {
    api_groups = [""]
    resources  = ["secrets"]
    verbs      = ["create", "delete"]
  }
  rule {
    api_groups = [""]
    resources  = ["pods", "pods/log"]
    verbs      = ["get", "create", "delete", "list", "watch", "update"]
  }
}

resource "kubernetes_role_binding" "drone_runner" {
  metadata {
    name      = "drone-runner"
    namespace = kubernetes_namespace.drone_builds.metadata[0].name
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.drone_runner.metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.drone_runner.metadata[0].name
    namespace = local.drone_namespace
  }
}

resource "kubernetes_secret" "drone_runner_rpc" {
  metadata {
    name      = "drone-runner-rpc"
    namespace = local.drone_namespace
  }
  data       = { secret = var.drone_rpc_secret }
  depends_on = [helm_release.drone]
}

# Its labels must not be the server's (app.kubernetes.io/name: drone): the
# server's Service would send the web UI's traffic to the runner as well.
# Not privileged and no host mounts: the kubernetes runner only talks to the
# API server. Each pod is a runner of its own (named after the pod); the
# server hands a build to whichever asks first.
resource "kubectl_manifest" "drone-runner" {
  yaml_body = <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: drone-runner
  namespace: ${local.drone_namespace}
  labels:
    app.kubernetes.io/name: drone-runner
spec:
  replicas: ${var.drone_runner_replicas}
  selector:
    matchLabels:
      app.kubernetes.io/name: drone-runner
  template:
    metadata:
      labels:
        app.kubernetes.io/name: drone-runner
    spec:
      serviceAccountName: ${kubernetes_service_account.drone_runner.metadata[0].name}
      containers:
      - name: runner
        image: drone/drone-runner-kube:latest
        ports:
        - containerPort: 3000
        env:
        - name: DRONE_RPC_HOST
          value: drone.${local.drone_namespace}:8080
        - name: DRONE_RPC_PROTO
          value: http
        - name: DRONE_RPC_SECRET
          valueFrom:
            secretKeyRef:
              name: ${kubernetes_secret.drone_runner_rpc.metadata[0].name}
              key: secret
        - name: DRONE_NAMESPACE_DEFAULT
          value: ${kubernetes_namespace.drone_builds.metadata[0].name}
EOF
  depends_on = [
    helm_release.drone,
    kubernetes_role_binding.drone_runner,
  ]
}
