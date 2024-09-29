provider "helm" {
  kubernetes {
    config_path = "/home/bmath/k8s/u51/kubeconfig.yaml"
  }
}
provider "kubernetes" {
  config_path = "/home/bmath/k8s/u51/kubeconfig.yaml"
}

resource "helm_release" "metallb" {
  name = "metallb"
  repository = "https://metallb.github.io/metallb"
  chart      = "metallb"
  namespace  = "kube-system"
}

resource "kubernetes_manifest" "metallb-ip" {
  manifest = {    "apiVersion" = "metallb.io/v1beta1"
    "kind"       = "IPAddressPool"
    "metadata"   = {
      "name"      = "metallb-ip"
      "namespace" = "metallb-system"
    }
    "spec"        = {
      "addresses" = [ "10.23.55.8/32" ]
    }
  }
}


resource "helm_release" "nginx-ingress" {
  name       = "nginx-ingress-controller"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "nginx-ingress-controller"
  namespace  = "kube-system"
  set {
    name  = "service.type"
    value = "LoadBalancer"
  }
}

resource "kubernetes_service_v1" "nginx-ingress" {
  metadata {
    name = "nginx-ingress"
    namespace = "kube-system"
  }
  spec {
    port {
      name        = "https"
      protocol    = "TCP"
      port        = 443
      target_port = "https"
    }
    type = "LoadBalancer"
  }
  depends_on = [
    helm_release.nginx-ingress
  ]
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
    server = "10.23.55.1"
    share = "/export/gram-vg--nfs"
  }
  mount_options = ["nfsvers=4.2"]
  depends_on = [
    helm_release.nfs
  ]
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
    helm_release.nfs
  ]
}
resource "kubernetes_ingress" "gitea" {
  metadata {
    name = "gitea"
    namespace = "gitea"
  }
  spec {
    ingress_class_name = "nginx"
    rule {
      http {
        path {
          path = "/*"
          backend {
            service_name = "gitea-http"
            service_port =  3000
          }
        }
      }
    }
  }
  depends_on = [
    helm_release.gitea
  ]
}


resource "helm_release" "minio" {
  name       = "minio"
  repository = "https://charts.min.io/"
  chart      = "minio"
  namespace  = "minio"
  create_namespace = true

  set {
    name  = "rootUser"
    value = "admin"
  }
  set {
    name  = "rootPassword"
    value = "r"
  }
  set {
    name  = "resources.requests.memory"
    value = "512Mi"
  }
  set {
    name  = "replicas"
    value = "1"
  }
  set {
    name  = "persistence.enabled"
    value = "true"
  }
  set {
    name  = "mode"
    value = "standalone"
  }
  depends_on = [
    helm_release.nfs
  ]
}
resource "kubernetes_ingress" "minio" {
  metadata {
    name = "minio"
    namespace = "minio"
  }
  spec {
    ingress_class_name = "nginx"
    rule {
      http {
        path {
          path = "/*"
          backend {
            service_name = "minio-http"
            service_port =  3000
          }
        }
      }
    }
  }
  depends_on = [
    helm_release.minio
  ]
}


# resource "helm_release" "velero" {
#   name       = "velero"
#   repository = "https://vmware-tanzu.github.io/helm-charts"
#   chart      = "velero"
#   namespace  = "velero"
#   create_namespace = true
#   set {
#     name  = "credentials.secretContents.cloud"
#     value = ""
#   }

#   set {
#     name = "configuration.backupStorageLocation[0].name"
#     value = ""
#   }
#   set {
#     name = "configuration.backupStorageLocation[0].provider"
#     value = ""
#   }
#   set {
#     name = "configuration.backupStorageLocation[0].bucket"
#     value = ""
#   }
#   set {
#     name = "configuration.backupStorageLocation[0].config.region"
#     value = ""
#   }
#   set {
#     name = "configuration.volumeSnapshotLocation[0].name"
#     value = ""
#   }
#   set {
#     name = "configuration.volumeSnapshotLocation[0].provider"
#     value = ""
#   }
#   set {
#     name = "configuration.volumeSnapshotLocation[0].config.region"
#     value = ""
#   }
#   set {
#     name = "initContainers[0].name"
#     value = ""
#   }
#   set {
#     name = "initContainers[0].image"
#     value = ""
#   }
#   set {
#     name = "initContainers[0].volumeMounts[0].mountPath"
#     value = ""
#   }
#   set {
#     name = "initContainers[0].volumeMounts[0].name"
#     value = ""
#   }
#   depends_on = [
#     helm_release.nfs
#   ]
# }
# resource "kubernetes_ingress" "velero" {
#   metadata {
#     name = "velero"
#     namespace = "velero"
#   }
#   spec {
#     ingress_class_name = "nginx"
#     rule {
#       http {
#         path {
#           path = "/*"
#           backend {
#             service_name = ""
#             service_port =  80
#           }
#         }
#       }
#     }
#   }
#   depends_on = [
#     helm_release.velero
#   ]
# }
