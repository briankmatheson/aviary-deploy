resource "helm_release" "drone" {
  name       = "drone"
  repository = "https://charts.drone.io"
  chart      = "drone"
  namespace  = "drone"
  create_namespace = true

  
  values = [
    <<EOF
    ingress.enabled: true
    ingress.className: "nginx"
    ingress.hosts[0].host: "drone.local"
    ingress.hosts[0].paths[0].path: "/"
    ingress.hosts[0].paths[0].pathType: "Prefix"
    env.DRONE_NAMESPACE_DEFAULT: "drone"
    env.DRONE_SERVER_PROTO: "https"
    env.DRONE_RPC_SECRET: "0xdeadbeef"
    env.DRONE_SERVER_HOST: "drone"
    env.DRONE_GITEA_SERVER: "https://gitea"
    env.DRONE_GITEA_CLIENT_ID: "3b44aa85-1dcb-4efd-a902-13063eb5df6c"
    env.DRONE_GITEA_CLIENT_SECRET: "gto_ngd4yuzkc35mjveyhrkbz63slphhyqvxcx6qe5oecgtmuykhsafq"
EOF
  ]
  depends_on = [
    helm_release.gitea ]
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
  namespace: drone
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
  namespace: drone
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
  namespace: drone
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
      initContainers:
      - name: init-myservice
        image: drone/drone-runner-kube:latest
        command: ['sh', '-c', "apk add ca-certificates && update-ca-certificates"]
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
          value: drone:8080
        - name: DRONE_RPC_PROTO
          value: http
        - name: DRONE_RPC_SECRET
          value: "0xdeadbeef"
        - name: DRONE_LOGS_DEBUG
          value: "true"
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
