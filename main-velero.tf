resource "helm_release" "velero" {
  name       = "velero"
  repository = "https://vmware-tanzu.github.io/helm-charts"
  chart      = "velero"
  namespace  = "velero"
  create_namespace = true
  set = [
    {
      name  = "credentials.secretContents.cloud"
      value = var.velero_credentials_secret
    },
    
    {
      name = "configuration.backupStorageLocation[0].name"
      value = var.velero_backup_storage_name
    },
    {
      name = "configuration.backupStorageLocation[0].provider"
      value = var.velero_backup_storage_provider
    },
    {
      name = "configuration.backupStorageLocation[0].bucket"
      value = var.velero_backup_storage_bucket
    },
    {
      name = "configuration.backupStorageLocation[0].config.region"
      value = var.velero_backup_storage_region
    },
    {
      name = "configuration.volumeSnapshotLocation[0].name"
      value = var.velero_snapshot_location_name
    },
    {
      name = "configuration.volumeSnapshotLocation[0].provider"
      value = var.velero_snapshot_location_provider
    },
    {
      name = "configuration.volumeSnapshotLocation[0].config.region"
      value = var.velero_snapshot_location_region
    },
    {
      name = "initContainers[0].name"
      value = var.velero_init_container_name
    },
    {
      name = "initContainers[0].image"
      value = var.velero_init_container_image
    },
    {
      name = "initContainers[0].volumeMounts[0].mountPath"
      value = var.velero_init_container_mount_path
    },
    {
      name = "initContainers[0].volumeMounts[0].name"
      value = var.velero_init_container_volume_name
    }
  ]
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
