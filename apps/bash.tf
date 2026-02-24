resource "helm_release" "bash" {
  name       = "bash"
  repository = "https://cloudtty.github.io/cloudtty"
  chart      = "cloudtty"
  namespace  = "bash"
  create_namespace = true
  depends_on = [
    helm_release.dashboard,
    helm_release.ingress-nginx
  ]
}
resource "kubectl_manifest" "bash" {
  yaml_body = <<EOF
apiVersion: cloudshell.cloudtty.io/v1alpha1
kind: CloudShell
metadata:
  name: aviary-bash
  namespace: default
spec:
  exposureMode: ClusterIP
  image: nicolaka/netshoot
  commandAction: "bash"
  once: false
EOF
  depends_on = [
    helm_release.dashboard,
    helm_release.bash,
  ]
}
resource "kubernetes_ingress_v1" "bash" {
  metadata {
    name = "bash" 
    namespace = "default"
    annotations = {
      "kubernetes.io/ingress.class" = "nginx",
      "cert-manager.io/cluster-issuer" =  "ca-issuer"
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
    tls {
      secret_name = "cloudtty-tls"
      hosts = [ "bash.local" ]
    }
  }
  depends_on = [
    helm_release.ingress-nginx,
    kubectl_manifest.bash
  ]
}
