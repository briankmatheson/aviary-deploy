# gitea is a github-like git server that can be self-hosted.  There
# are a wide variety of install options which can be gleaned from the
# chart's values file.  We set a subset here to support
# * persistence via our standard nfs storage class
# * ssh support via a separate lb IP
# * tls for http interfaces
#
# NOTE: Most of the redundancy functionality is turned off.
resource "helm_release" "gitea" {
  name       = "gitea"
  chart      = "gitea"
  repository = "https://dl.gitea.io/charts/"
  namespace  = "gitea"
  create_namespace = true
  /*
  values = [ <<EOF
admin:
  password: admin
global:
  storageClass: standard
ssh:
  externalHost: bash.local
  loadBalancerIP: 192.168.123.10
ingress:
  hosts:
    - gitea.local
    - ssh.gitea.local
redis:
  enabled: true
postgresql:
  enabled: true
gitea:
  config:
    server:
      ROOT_URL: "https://gitea.local/"
service:
  ssh:
    enabled: true 
    type: LoadBalancer
    port: 2222 
    externalPort: 22 
EOF
  ]
*/
  values = [
    <<EOF
    admin.password: var.gitea_admin_password
    global.storageClass: var.global_storage_class
    ssh.externalHost: var.ssh_external_host
    ssh.loadBalancerIP: var.ssh_load_balancer_ip
    ingress.hosts: join(",", var.ingress_hosts)
    redis.enabled: var.redis_enabled
    postgresql.enabled: var.postgresql_enabled
EOF
  ]
  
   
  depends_on = [
    helm_release.redis,
    helm_release.postgres,
  ]
}

resource "kubernetes_ingress_v1" "gitea" {
  metadata {
    name = "gitea"
    namespace = "gitea"
    annotations = {
      "kubernetes.io/ingress.class" = "nginx",
      "cert-manager.io/cluster-issuer" =  "ca-issuer"
    }
  }
  depends_on = [
    helm_release.gitea
  ]
  spec {
    ingress_class_name = "nginx"
    rule {
      host = "gitea.local"
      http {
        path {
          path = "/"
          backend {
            service {
	              name = "gitea-http"
                port {
		             number = 3000
	             }   
	           }   
           }
          }
       }
      }
    tls {
      secret_name = "gitea-tls"
      hosts = [ "gitea.local", "gitea" ]
    }
  }
}
resource "kubectl_manifest" "drone" {
  yaml_body = <<EOF
apiVersion: v1
kind: Service
metadata:
  labels:
    app: drone
  name: drone
  namespace: 
spec:
  externalName: ingress-nginx-controller.ingress-nginx.svc.cluster.local
  selector:
    app: drone
  sessionAffinity: None
  type: ExternalName
EOF
  depends_on = [
    kubernetes_ingress_v1.gitea,
  ]
}
