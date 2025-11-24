resource "helm_release" "qdrant" {
  name       = "qdrant"
  repository = "https://qdrant.github.io/qdrant-helm"
  chart      = "qdrant"
  namespace  = "qdrant"
  create_namespace = true

  values = [<<EOF
config:
  ingress:
    enabled: true
    ingressClassName: "nginx"
    hosts:
      - host: qdrant.local
        paths:
          - path: /
            pathType: Prefix
            servicePort: 6333
    tls:
      - hosts:
          - qdrant.local
        secretName: qdrant-tls
EOF
  ]
}
resource "kubernetes_ingress_v1" "qdrant" {
  wait_for_load_balancer = true
  metadata {
    name = "qdrant" 
    namespace = "qdrant"
    annotations = {
      "kubernetes.io/ingress.class" = "nginx"
      "cert-manager.io/cluster-issuer" = "ca-issuer"
    }
  }
  spec {
    ingress_class_name = "nginx"
    rule {
      host = "qdrant.local"
      http {
        path {
          path = "/"
          backend {
            service {
	      name = "qdrant"
              port {
		number = 80
	      }
	    }
          }
        }
      }
    }
    tls {
      secret_name = "qdrant-tls"
      hosts = [ "qdrant.local" ]
    }
  }
  depends_on = [
    helm_release.qdrant,
    helm_release.ingress-nginx
  ]
}
