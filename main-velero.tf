resource "helm_release" "velero" {
  name       = "velero"
  repository = "https://vmware-tanzu.github.io/helm-charts"
  chart      = "velero"
  namespace  = "velero"
  create_namespace = true
  values = [
    <<EOF
    credentials.secretContents.cloud: var.velero_credentials_secret
    configuration.backupStorageLocation[0].name: var.velero_backup_storage_name
    configuration.backupStorageLocation[0].provider: var.velero_backup_storage_provider
    configuration.backupStorageLocation[0].bucket: var.velero_backup_storage_bucket
    configuration.backupStorageLocation[0].config.region: var.velero_backup_storage_region
    configuration.volumeSnapshotLocation[0].name: var.velero_snapshot_location_name
    configuration.volumeSnapshotLocation[0].provider: var.velero_snapshot_location_provider
    configuration.volumeSnapshotLocation[0].config.region: var.velero_snapshot_location_region
    initContainers[0].name: var.velero_init_container_name
    initContainers[0].image: var.velero_init_container_image
    initContainers[0].volumeMounts[0].mountPath: var.velero_init_container_mount_path
    initContainers[0].volumeMounts[0].name: var.velero_init_container_volume_name
EOF
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
