resource "helm_release" "velero" {
  name             = "velero"
  repository       = "https://vmware-tanzu.github.io/helm-charts"
  chart            = "velero"
  namespace        = "${var.ns_prefix}velero"
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
      # The chart renders a VolumeSnapshotLocation unconditionally; it needs
      # a provider or the API server rejects it.
      volumeSnapshotLocation = [{
        name     = var.velero_backup_storage_name
        provider = var.velero_backup_storage_provider
        config   = { region = var.velero_backup_storage_region }
      }]
    }
    initContainers = [{
      name            = "velero-plugin-for-${var.velero_backup_storage_provider}"
      image           = "velero/velero-plugin-for-${var.velero_backup_storage_provider}:v1.13.0"
      imagePullPolicy = "IfNotPresent"
      volumeMounts    = [{ name = "plugins", mountPath = "/target" }]
    }]
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
# Exposure handled by the shared Envoy Gateway (velero.<base_domain> -> velero:8085).
