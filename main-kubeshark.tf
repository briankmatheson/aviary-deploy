resource "helm_release" "kubeshark" {
  name       = "kubeshark"
  repository = "https://helm.kubeshark.co"
  chart      = "kubeshark"
  namespace  = "kubeshark"
  create_namespace = true
  values = [ <<EOF
persistence.enabled: true
EOF
  ]
}
  resource "kubernetes_ingress_v1" "kubeshark" {
  wait_for_load_balancer = true
  metadata {
    name = "kubeshark" 
    namespace = "kubeshark"
    annotations = {
      "kubernetes.io/ingress.class" = "nginx"
      "cert-manager.io/cluster-issuer" = "ca-issuer"
    }
  }
  spec {
    ingress_class_name = "nginx"
    rule {
      host = "kubeshark.local"
      http {
        path {
          path = "/"
          backend {
            service {
	      name = "kubeshark-hub"
              port {
		number = 80
	      }
	    }
          }
        }
      }
    }
    tls {
      secret_name = "kubeshark-tls"
      hosts = [ "kubeshark.local" ]
    }
  }
  depends_on = [
    helm_release.kubeshark,
    helm_release.ingress-nginx
  ]
}
