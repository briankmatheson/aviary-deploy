resource "helm_release" "grafana" {
  name       = "grafana"
  chart      = "grafana"
  repository = "https://grafana.github.io/helm-charts"
  namespace  = "grafana"
  create_namespace = true

  set {
    name  = "adminPassword"
    value = "admin"
  }

  depends_on = [
    kubernetes_storage_class.standard,
    helm_release.ingress-nginx,
    helm_release.prometheus,
  ]
}
resource "kubernetes_ingress_v1" "grafana" {
  wait_for_load_balancer = true
  metadata {
    name = "grafana"
    namespace = "grafana"
    annotations = {
      "kubernetes.io/ingress.class" = "nginx",
      "cert-manager.io/cluster-issuer" =  "ca-issuer"
    }
  }
  spec {
    ingress_class_name = "nginx"
    rule {
      host = "grafana.local"
      http {
        path {
          path = "/"
          backend {
            service {
	      name = "grafana"
              port {
		number = 80
	      }
	    }
          }
        }
      }
    }
    tls {
      secret_name = "grafana-tls"
      hosts = [ "grafana" ]
    }
  }
  depends_on = [
    helm_release.grafana
  ]
}
