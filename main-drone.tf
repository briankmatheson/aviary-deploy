resource "helm_release" "drone" {
  name       = "drone"
  repository = "https://charts.drone.io"
  chart      = "drone"
  namespace  = "drone"
  create_namespace = true

  set {
    name = "ingress.enabled"
    value = true
  }
  set {
    name = "ingress.className"
    value = "nginx"
  }
  set {
    name = "ingress.hosts[0].host"
    value = "drone.local"
  }
  set {
    name = "ingress.hosts[0].paths[0].path"
    value = "/"
  }
  set {
    name = "ingress.hosts[0].paths[0].pathType"
    value = "Prefix"
  }
  set {
    name = "env.DRONE_NAMESPACE_DEFAULT"
    value = "drone"
  }
  set {
    name = "env.DRONE_SERVER_HOST"
    value = "drone.local"
  }
  set {
    name = "env.DRONE_SERVER_PROTO"
    value = "https"
  }
  set {
    name = "env.DRONE_RPC_SECRET"
    value = "0xdeadbeef"
  }
  set {
    name = "env.DRONE_GITEA_SERVER"
    value = "https://gitea"
  }
  set {
    name = "env.DRONE_GITEA_CLIENT_ID"
    value = "6e7195ca-f7ca-4847-ad84-ed2b1cb42c16"
  }
  set {
    name = "env.DRONE_GITEA_CLIENT_SECRET"
    value = "gto_4gelppl5xtwr7jvpin7lhojvmutkzezpajpy7peetdxtoipvptyq"
  }
  depends_on = [
    helm_release.dashboard,
    helm_release.ingress-nginx,
    helm_release.nfs
  ]
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
  externalName: ingress-nginx-controller.ingress-nginx.svc.cluster.local
  selector:
    app: gitea
  sessionAffinity: None
  type: ExternalName
EOF
  depends_on = [
    helm_release.drone
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
  namespace: drone
EOF
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
          value: "0xdeadbeef"
      volumes:
      - name: run
        hostPath:
          path: /var/run
          type: Directory
EOF
  depends_on = [
    kubectl_manifest.drone-rolebindings,
    kubectl_manifest.drone-role
  ]
}
