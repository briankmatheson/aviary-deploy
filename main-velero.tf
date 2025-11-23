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

    deployNodeAgent: true
        
    schedules.hourly.schedule: "23 * * * *"
    schedules.hourly.template.includeClusterResources: true
    schedules.hourly.template.includedNamespaces[0]: '*'
    schedules.hourly.template.includedResources[0]: '*'
    schedules.hourly.template.storageLocation: aws
    schedules.hourly.template.snapshotVolumes: true      
    schedules.hourly.template.ttl: 72h0m0s```
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
