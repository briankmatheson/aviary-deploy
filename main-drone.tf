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
    value = "drone-runner"
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
    value = "http://gitea"
  }
  set {
    name = "env.DRONE_GITEA_CLIENT_ID"
    value = "5e58c6f5-e192-4aec-951a-85efddc5bcd2"
  }
  set {
    name = "env.DRONE_GITEA_CLIENT_SECRET"
    value = "gto_t6tk4atcqemhiqhj7a7lsqkh65qehtiduixbwremkhxbnkkvluaq"
  }
  depends_on = [
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
    helm_release.drone,
    kubernetes_ingress_v1.cloudtty
  ]
}
