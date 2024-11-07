provider "helm" {
  kubernetes {
    config_path = "/home/bmath/k8s/u98/kubeconfig.yaml"
  }
}
provider "kubernetes" {
  config_path = "/home/bmath/k8s/u98/kubeconfig.yaml"
}

# resource "helm_release" "metallb" {
#   name = "metallb"
#   repository = "https://metallb.github.io/metallb"
#   chart      = "metallb"
#   namespace  = "kube-system"
# }


resource "kubernetes_manifest" "metallb-ip" {
  manifest = {    "apiVersion" = "metallb.io/v1beta1"
    "kind"       = "IPAddressPool"
    "metadata"   = {
      "name"      = "metallb-ip"
      "namespace" = "metallb-system"
    }
    "spec"        = {
      "addresses" = [ "10.23.98.8/32" ]
    }
  }
}


resource "helm_release" "ingress-nginx" {
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  namespace  = "ingress-nginx"
  create_namespace = true
  set {
    name  = "service.type"
    value = "LoadBalancer"
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
    name = "fast-nfs"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }
  storage_provisioner = "nfs.csi.k8s.io"
  reclaim_policy      = "Delete"
  volume_binding_mode = "WaitForFirstConsumer"
  parameters = {
    server = "10.23.98.1"
    share = "/export/fast-nfs"
  }
  mount_options = ["nfsvers=4.2"]
  depends_on = [
    helm_release.nfs
  ]
}
resource "kubernetes_storage_class" "standard" {
  metadata {
    name = "standard"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }
  storage_provisioner = "nfs.csi.k8s.io"
  reclaim_policy      = "Delete"
  volume_binding_mode = "WaitForFirstConsumer"
  parameters = {
    server = "10.23.98.1"
    share = "/export/fast-nfs"
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
resource "kubernetes_ingress_v1" "gitea" {
  wait_for_load_balancer = true
  metadata {
    name = "gitea"
    namespace = "gitea"
    annotations = {
      "kubernetes.io/ingress.class" = "nginx"
    }
  }
  spec {
    ingress_class_name = "nginx"
    rule {
      host = "gitea.local"
      http {
        path {
          path = "/"
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
  depends_on = [
    helm_release.ingress-nginx
  ]
}


resource "helm_release" "minio" {
  name       = "minio"
  repository = "https://operator.min.io"
  chart      = "minio-operator"
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
    name  = "servers"
    value = "1"
  }
  set {
    name  = "storageClassName"
    value = "fast-nfs"
  }
  set {
    name  = "mode"
    value = "standalone"
  }
  set {
    name = "ingress"
    value = true
  }
  depends_on = [
    helm_release.nfs
  ]
}
resource "kubernetes_ingress_v1" "minio" {
  wait_for_load_balancer = true
  metadata {
    name = "minio"
    namespace = "minio"
  }
  spec {
    ingress_class_name = "nginx"
    rule {
      host = "minio.local"
      http {
        path {
          path = "/"
          backend {
            service {
	      name = "minio1-hl"
              port {
		number = 9000
	      }
	    }
          }
        }
      }
    }
    rule {
      host = "minio-console.local"
      http {
	path {
          path = "/"
          backend {
            service {
	      name = "minio1-console"
              port {
		number = 9443
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


# Resource "Helm_Release" "Velero" {
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
