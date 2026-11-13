# DISABLED. These resources still use the old nginx Ingress and their own
# *_ingress_class/_host/_tls variables (declared below). To enable: move the
# file into apps/, system/ or data/, replace the Ingress with an entry in
# local.vhosts (system/envoy-gateway.tf), and drop the variables you no
# longer need.

resource "helm_release" "jitsi" {
  name             = "jitsi"
  repository       = "https://jitsi-contrib.github.io/jitsi-helm/"
  chart            = "jitsi-meet"
  namespace        = "jitsi"
  create_namespace = true

  values = [<<EOF
    jvb:
      publicIPs:
        - 192.168.123.10
      service:
        type: LoadBalancer
        ipFamilyPolicy: SingleStack
    publicURL: https://jitsi.local
    ingress:
      enabled: true
EOF
  ]
}
resource "kubernetes_ingress_v1" "jitsi" {
  wait_for_load_balancer = true
  metadata {
    name      = "jitsi"
    namespace = "jitsi"
    annotations = {
      "kubernetes.io/ingress.class"    = "nginx"
      "cert-manager.io/cluster-issuer" = "ca-issuer"
    }
  }
  spec {
    ingress_class_name = "nginx"
    rule {
      host = "jitsi.local"
      http {
        path {
          path = "/"
          backend {
            service {
              name = "jitsi-jitsi-meet-web"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
    tls {
      secret_name = "jitsi-tls"
      hosts       = ["jitsi.local"]
    }
  }
  depends_on = [
    helm_release.jitsi,
    helm_release.ingress-nginx
  ]
}
