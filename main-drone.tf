resource "helm_release" "drone" {
  name       = "drone"
  repository = "https://charts.drone.io"
  chart      = "drone"
  namespace  = "drone"
  create_namespace = true

  values = [
    <<EOF


ingress:
  hosts:
    - host: "drone.local"
      paths:
        -  path: /
           pathType: Prefix
env:
  DRONE_SERVER_HOST: drone.local
  DRONE_GITEA_SERVER: http://gitea
  DRONE_GITEA_CLIENT_ID: 742cce17-0aa6-4a59-a883-975edf8bfe1e
  DRONE_GITEA_CLIENT_SECRET: gto_zhrxwvmaxmk2yft5xlf6n5pljvig6bjk4ndl64cfgofvk6sav5ta
  DRONE_RPC_SECRET: "0xdeadbeef"
EOF
  ]

  depends_on = [
    helm_release.gitea,
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


resource "kubernetes_ingress_v1" "drone" {
  metadata {
    name = "drone"
    namespace = "drone"
    annotations = {
      "kubernetes.io/ingress.class" = "nginx",
      "cert-manager.io/cluster-issuer" =  "ca-issuer"
    }
  }
  depends_on = [
    helm_release.drone
  ]
  spec {
    ingress_class_name = "nginx"
    rule {
      host = "drone.local"
      http {
        path {
          path = "/"
          backend {
            service {
	              name = "drone" 
                port {
		             number = 8080
	             }   
	           }   
           }
          }
       }
      }
    tls {
      secret_name = "drone-tls"
      hosts = ["drone.local"]
    }
  }
}
