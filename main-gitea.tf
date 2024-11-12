resource "helm_release" "gitea" {
  name       = "gitea"
  repository = "https://dl.gitea.com/charts/"
  chart      = "gitea"
  namespace  = "gitea"
  create_namespace = true

  set {
    name = "global.storageClass"
    value = "standard"
  }
  set {
    name = "global.hostAliases[0].ip"
    value = "10.23.98.8"
  }
  set {
    name = "global.hostAliases[0].hostnames[0]"
    value = "gitea.local"
  }
  set {
    name = "service.ssh.externalHost"
    value = "gitea.local"
  }
  set {
    name  = "service.ssh.type"
    value = "LoadBalancer"
  }
  set {
    name = "service.ssh.loadBalancerIP"
    value = "10.23.98.7"
  }
  set {
    name = "ingress.hosts[0].host"
    value = "ssh.gitea.local"
  }
  depends_on = [
    helm_release.nfs
  ]
}
resource "kubernetes_ingress_v1" "gitea" {
  wait_for_load_balancer = true
  metadata {
    name = "gitea"
    namespace = "gitea"
    annotations = {
      "kubernetes.io/ingress.class" = "nginx"
    }
  }
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
  }
  depends_on = [
    helm_release.nfs
  ]
}


