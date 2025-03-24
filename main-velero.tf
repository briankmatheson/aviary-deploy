resource "helm_release" "velero" {
  name       = "velero"
  repository = "https://vmware-tanzu.github.io/helm-charts"
  chart      = "velero"
  namespace  = "velero"
  create_namespace = true
  set {
    name  = "credentials.secretContents.cloud"
    value = ""
  }

  set {
    name = "configuration.backupStorageLocation[0].name"
    value = ""
  }
  set {
    name = "configuration.backupStorageLocation[0].provider"
    value = ""
  }
  set {
    name = "configuration.backupStorageLocation[0].bucket"
    value = ""
  }
  set {
    name = "configuration.backupStorageLocation[0].config.region"
    value = ""
  }
  set {
    name = "configuration.volumeSnapshotLocation[0].name"
    value = ""
  }
  set {
    name = "configuration.volumeSnapshotLocation[0].provider"
    value = ""
  }
  set {
    name = "configuration.volumeSnapshotLocation[0].config.region"
    value = ""
  }
  set {
    name = "initContainers[0].name"
    value = ""
  }
  set {
    name = "initContainers[0].image"
    value = ""
  }
  set {
    name = "initContainers[0].volumeMounts[0].mountPath"
    value = ""
  }
  set {
    name = "initContainers[0].volumeMounts[0].name"
    value = ""
  }
  depends_on = [
    helm_release.dashboard,
  ]
}
resource "kubernetes_ingress_v1" "velero" {
  metadata {
    name = "velero"
    namespace = "velero"
  }
  spec {
    ingress_class_name = "nginx"
    rule {
      host = "velero.local"
      http {
        path {
          path = "/"
          backend {
	    service {
	      name = "velero"
              port {
		number = 8085
	      }
	    }
          }
        }
      }
    }
    tls {
      secret_name = "velero-tls"
      hosts = [ "velero.local" ]
    }
  }
  depends_on = [
    helm_release.velero
  ]
}
