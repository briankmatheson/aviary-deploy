# DISABLED. These resources still use the old nginx Ingress and their own
# *_ingress_class/_host/_tls variables (declared below). To enable: move the
# file into apps/, system/ or data/, replace the Ingress with an entry in
# local.vhosts (system/envoy-gateway.tf), and drop the variables you no
# longer need.

variable "jupyterhub_namespace" { default = "jupyterhub" }
variable "jupyterhub_host" { default = "jupyterhub.local" }
variable "jupyterhub_tls_secret_name" { default = "jupyterhub-tls" }
variable "jupyterhub_ingress_class" { default = "nginx" }
variable "jupyterhub_cluster_issuer" { default = "ca-issuer" }

resource "helm_release" "jupyterhub" {
  name             = "jupyterhub"
  chart            = "jupyterhub"
  repository       = "https://hub.jupyter.org/helm-chart/"
  namespace        = var.jupyterhub_namespace
  create_namespace = true

  values = [<<EOF
hub:
  revisionHistoryLimit:
  config:
    Authenticator:
      admin_users:
        - admin
      allowed_users:
        - bmath
    DummyAuthenticator:
      password: yow
    JupyterHub:
      admin_access: true
      authenticator_class: dummy
EOF
  ]

  depends_on = [
    helm_release.dashboard,
  ]
}

resource "kubernetes_ingress_v1" "jupyterhub" {
  metadata {
    name      = "jupyterhub"
    namespace = var.jupyterhub_namespace
    annotations = {
      "kubernetes.io/ingress.class"    = var.jupyterhub_ingress_class
      "cert-manager.io/cluster-issuer" = var.jupyterhub_cluster_issuer
    }
  }
  spec {
    ingress_class_name = var.jupyterhub_ingress_class
    rule {
      host = var.jupyterhub_host
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
      secret_name = var.jupyterhub_tls_secret_name
      hosts       = [var.jupyterhub_host]
    }
  }
  depends_on = [
    helm_release.jupyterhub
  ]
}
