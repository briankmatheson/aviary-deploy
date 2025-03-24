
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
  repository = "https://dl.gitea.com/charts/"
  chart      = "gitea"
  namespace  = "gitea"
  create_namespace = true

  set {
    name = "gitea.admin.password"
    value = "rrrrrrrr"
  }
  set {
    name = "global.storageClass"
    value = "standard"
  }
  set {
    name = "global.hostAliases[0].ip"
    value = "192.168.122.7"
  }
  set {
    name = "global.hostAliases[1].ip"
    value = "192.168.122.9"
  }
  set {
    name = "global.hostAliases[1].hostnames[0]"
    value = "ssh.gitea.local"
  }
  set {
    name = "global.hostAliases[0].hostnames[0]"
    value = "gitea"
  }
  set {
    name = "service.ssh.externalHost"
    value = "ssh.gitea.local"
  }
  set {
    name  = "service.ssh.type"
    value = "LoadBalancer"
  }
  set {
    name = "service.ssh.loadBalancerIP"
    value = "192.168.122.9"
  }
  set {
    name = "ingress.hosts[0].host"
    value = "gitea"
  }
  set {
    name = "ingress.hosts[1].host"
    value = "gitea.local"
  }
  set {
    name = "ingress.hosts[2].host"
    value = "ssh.gitea.local"
  }
  set {
    name = "redis-cluster.enabled"
    value = false
  }
  set {
    name = "redis.enabled"
    value = true
  }
  set {
    name = "postgresql-ha.enabled"
    value = false
  }
  set {
    name = "postgresql.enabled"
    value = true
  }
  depends_on = [
    helm_release.dashboard,
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
      host = "gitea"
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
      hosts = [ "gitea" ]
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
  namespace: gitea
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
