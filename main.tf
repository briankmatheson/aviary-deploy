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
  chart      = "operator"
  namespace  = "minio"
  create_namespace = true

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

resource "helm_release" "postgres" {
  name       = "postgres"
  repository = "https://percona.github.io/percona-helm-charts/"
  chart      = "pg-operator"
  namespace  = "percona-postgres"
  create_namespace = true
  depends_on = [
    helm_release.nfs
  ]
}

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
      host = "cloudtty.local"
      http {
        path {
          path = "/"
          backend {
            service {
	      name = "cloudtty-server"
              port {
		number = 80
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
