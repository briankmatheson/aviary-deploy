resource "helm_release" "cloudtty" {
  name       = "cloudtty"
  repository = "https://cloudtty.github.io/cloudtty"
  chart      = "cloudtty"
  namespace  = "cloudtty"
  create_namespace = true
}
resource "kubernetes_ingress_v1" "cloudtty" {
  wait_for_load_balancer = true
  metadata {
    name = "cloudtty" 
    namespace = "cloudtty"
    annotations = {
      "kubernetes.io/ingress.class" = "nginx"
    }
  }
  spec {
    ingress_class_name = "nginx"
    rule {
      host = "bash.local"
      http {
        path {
          path = "/"
          backend {
            service {
	      name = "cloudshell-aviary-bash"
              port {
		number = 7681
	      }
	    }
          }
        }
      }
    }
  }
  depends_on = [
    helm_release.ingress-nginx
  ]
}
resource "kubectl_manifest" "cloudtty" {
  yaml_body = <<EOF
apiVersion: cloudshell.cloudtty.io/v1alpha1
kind: CloudShell
metadata:
  name: aviary-bash
  namespace: cloudtty
spec:
  commandAction: "bash"
  once: false
EOF
  depends_on = [
    helm_release.cloudtty,
    kubernetes_ingress_v1.cloudtty
  ]
}
