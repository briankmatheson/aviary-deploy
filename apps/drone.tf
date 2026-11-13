resource "helm_release" "drone" {
  name             = "drone"
  repository       = "https://charts.drone.io"
  chart            = "drone"
  namespace        = "drone"
  create_namespace = true

  # Ingress disabled; routed via the shared Envoy Gateway (see envoy-gateway.tf).
  # The Gitea OAuth2 client comes from terraform.tfvars (two-phase install,
  # see README). gitea lives in the data/ stack; apply data/ before apps/.
  values = [yamlencode({
    ingress          = { enabled = false }
    persistentVolume = { storageClass = var.global_storage_class }
    env = {
      DRONE_SERVER_HOST         = "drone.local"
      DRONE_SERVER_PROTO        = "https"
      DRONE_GITEA_SERVER        = "https://gitea.local"
      DRONE_GITEA_CLIENT_ID     = var.drone_gitea_client_id
      DRONE_GITEA_CLIENT_SECRET = var.drone_gitea_client_secret
      DRONE_RPC_SECRET          = var.drone_rpc_secret
      DRONE_USER_CREATE         = "username:gitea_admin,machine:false,admin:true"
    }
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
  namespace: drone
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
resource "kubectl_manifest" "drone-role" {
  yaml_body = <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  annotations:
  name: drone
  namespace: default
rules:
- apiGroups:
  - ""
  resources:
  - secrets
  verbs:
  - create
  - delete
- apiGroups:
  - ""
  resources:
  - pods
  - pods/log
  verbs:
  - get
  - create
  - delete
  - list
  - watch
  - update
EOF
  depends_on = [
    helm_release.drone
  ]
}
resource "kubectl_manifest" "drone-rolebindings" {
  yaml_body = <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: drone
  namespace: default
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: drone
subjects:
- kind: ServiceAccount
  name: drone
  namespace: default
EOF
  depends_on = [
    helm_release.drone
  ]
}

resource "kubernetes_service_account" "drone" {
  metadata {
    name      = "drone"
    namespace = "default"
  }
  depends_on = [
    helm_release.drone
  ]
}

resource "kubectl_manifest" "drone-runner" {
  yaml_body = <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: drone-runner
  namespace: default
  labels:
    app.kubernetes.io/name: drone
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: drone
  template:
    metadata:
      labels:
        app.kubernetes.io/name: drone
    spec:
      serviceAccount: drone
      serviceAccountName: drone
      containers:
      - name: runner
        securityContext:
          privileged: true
        volumeMounts:
        - mountPath: /var/run
          name: run
        image: drone/drone-runner-kube:latest
        ports:
        - containerPort: 3000
        env:
        - name: DRONE_RPC_HOST
          value: drone.drone:8080
        - name: DRONE_RPC_PROTO
          value: http
        - name: DRONE_RPC_SECRET
          value: "${var.drone_rpc_secret}"
      volumes:
      - name: run
        hostPath:
          path: /var/run
          type: Directory
EOF
  depends_on = [
    helm_release.drone,
    kubernetes_service_account.drone
  ]
}
