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
  namespace  = var.gitea_namespace
  create_namespace = true

  set {
    name  = "admin.password"
    value = var.gitea_admin_password
  }
  set {
    name  = "global.storageClass"
    value = var.global_storage_class
  }
  set {
    name  = "ssh.externalHost"
    value = var.ssh_external_host
  }
  set {
    name  = "ssh.loadBalancerIP"
    value = var.ssh_load_balancer_ip
  }
  set {
    name  = "ingress.hosts"
    value = join(",", var.ingress_hosts)
  }
  set {
    name  = "redis.enabled"
    value = var.redis_enabled
  }
  set {
    name  = "postgresql.enabled"
    value = var.postgresql_enabled
  }

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
      host = var.ingress_hosts[0]
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
      hosts = var.ingress_hosts
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
