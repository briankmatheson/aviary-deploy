resource "helm_release" "drone" {
  name             = "drone"
  repository       = "https://charts.drone.io"
  chart            = "drone"
  namespace        = "${var.ns_prefix}drone"
  create_namespace = true

  # Ingress disabled; routed via the shared Envoy Gateway (see envoy-gateway.tf).
  # The Gitea OAuth2 client comes from terraform.tfvars (two-phase install,
  # see README). gitea lives in the system/ stack.
  values = [yamlencode({
    ingress          = { enabled = false }
    persistentVolume = { storageClass = var.global_storage_class }
    # RWO volume: a RollingUpdate deadlocks on the PVC the old pod holds.
    updateStrategy = { type = "Recreate" }
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
  })]
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
# API server.
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
  replicas: 1
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
        - name: DRONE_RUNNER_NAME
          value: aviary-drone-runner
EOF
  depends_on = [
    helm_release.drone,
    kubernetes_role_binding.drone_runner,
  ]
}
