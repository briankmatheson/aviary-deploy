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


/*
        - mountPath: /etc/ssl/certs
          name: ca-certs
          readOnly: true

      - configMap:
          defaultMode: 420 
          name: ca-certs
        name: ca-certs


*/
