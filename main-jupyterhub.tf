resource "helm_release" "jupyterhub" {
  name       = "jupyterhub"
  chart      = "jupyterhub"
  repository = "https://hub.jupyter.org/helm-chart/"
  namespace  = "jupyterhub"
  create_namespace = true


  depends_on = [
    helm_release.nfs,
    helm_release.ingress-nginx,
  ]
}
resource "kubernetes_ingress_v1" "jupyterhub" {
  wait_for_load_balancer = true
  metadata {
    name = "jupyterhub"
    namespace = "jupyterhub"
    annotations = {
      "kubernetes.io/ingress.class" = "nginx"
      "cert-manager.io/cluster-issuer" =  "ca-issuer"
    }
  }
  spec {
    ingress_class_name = "nginx"
    rule {
      host = "jupyterhub.local"
      http {
        path {
          path = "/"
          backend {
            service {
	      name = "proxy-public"
              port {
		number = 80
	      }
	    }
          }
        }
      }
    }
    tls {
      secret_name = "jupyternub-tls"
      hosts = [ "jupyterhub.local" ]
    }
  }
  depends_on = [
    helm_release.nfs,
    helm_release.ingress-nginx,
    helm_release.jupyterhub
  ]
}
