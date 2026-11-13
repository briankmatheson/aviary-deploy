resource "helm_release" "velero" {
  name             = "velero"
  repository       = "https://vmware-tanzu.github.io/helm-charts"
  chart            = "velero"
  namespace        = "velero"
  create_namespace = true

  # yamlencode() so the values nest; the chart ignores flat "a.b.c: v" keys.
  values = [yamlencode({
    credentials = {
      secretContents = { cloud = var.velero_credentials_secret }
    }
    configuration = {
      backupStorageLocation = [{
        name     = var.velero_backup_storage_name
        provider = var.velero_backup_storage_provider
        bucket   = var.velero_backup_storage_bucket
        config   = { region = var.velero_backup_storage_region }
      }]
    }
    deployNodeAgent = true
    schedules = {
      hourly = {
        schedule = "23 * * * *"
        template = {
          includeClusterResources = true
          includedNamespaces      = ["*"]
          includedResources       = ["*"]
          storageLocation         = var.velero_backup_storage_name
          snapshotVolumes         = true
          ttl                     = "72h0m0s"
        }
      }
    }
  })]
}
# Exposure handled by the shared Envoy Gateway (velero.local -> velero:8085).
