provider "helm" {
  kubernetes {
    config_path = "/home/bmath/k8s/u51/kubeconfig.yaml"
  }
}

provider "kubernetes" {
  config_path = "/home/bmath/k8s/u51/kubeconfig.yaml"
}

resource "helm_release" "nginx_ingress" {
  name       = "nginx-ingress-controller"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "nginx-ingress-controller"
  namespace  = "kube-system"
  set {
    name  = "service.type"
    value = "ClusterIP"
  }
}
resource "kubernetes_service_v1" "ingress" {
  metadata {
    name = "ingress"
  }
  spec {
    port {
      port        = 80
      target_port = 80
      protocol    = "TCP"
    }
    type = "NodePort"
  }
}

resource "helm_release" "nfs" {
  name       = "csi-driver-nfs"
  repository = "https://raw.githubusercontent.com/kubernetes-csi/csi-driver-nfs/master/charts"
  chart      = "csi-driver-nfs"
  namespace  = "kube-system"
}
resource "kubernetes_storage_class" "nfs" {
  metadata {
    name = "nfs"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }
  storage_provisioner = "nfs.csi.k8s.io"
  reclaim_policy      = "Delete"
  parameters = {
    server = "10.23.51.1"
    share = "/export/gram-vg--nfs"
  }
  mount_options = ["nfsvers=4.2"]
}

resource "helm_release" "gitea" {
  name       = "gitea"
  repository = "https://dl.gitea.com/charts/"
  chart      = "gitea"
  namespace  = "gitea"
  create_namespace = true
  
  set {
    name  = "service.type"
    value = "ClusterIP"
  }
  depends_on = [
    helm_release.nginx_ingress,
    helm_release.nfs
  ]
}
resource "kubernetes_ingress_v1" "example" {
  wait_for_load_balancer = true
  metadata {
    name = "gitea"
  }
  spec {
    ingress_class_name = "nginx"
    rule {
      http {
        path {
          path = "/*"
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
}
