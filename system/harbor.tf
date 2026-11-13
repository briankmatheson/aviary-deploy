resource "helm_release" "harbor" {
  name             = "harbor"
  repository       = "https://helm.goharbor.io"
  chart            = "harbor"
  namespace        = var.harbor_namespace
  create_namespace = true
  timeout          = 900 # eight pods + five abe volumes; 300s is too tight

  # TLS terminates at the Envoy Gateway; expose the core as a plain ClusterIP
  # Service and route to it via HTTPRoute (see envoy-gateway.tf).
  values = [yamlencode({
    expose = {
      type = "clusterIP"
      tls  = { enabled = false }
    }
    externalURL = var.harbor_external_url
    ipFamily    = { ipv6 = { enabled = var.harbor_ipv6_enabled } }
    # RWO block volumes: a RollingUpdate deadlocks (the new jobservice pod on
    # another node cannot attach the PVC the old one still holds).
    updateStrategy = { type = "Recreate" }
    # The cluster has no default StorageClass; pin every PVC to ours.
    persistence = {
      persistentVolumeClaim = {
        registry   = { storageClass = var.global_storage_class }
        jobservice = { jobLog = { storageClass = var.global_storage_class } }
        database   = { storageClass = var.global_storage_class }
        redis      = { storageClass = var.global_storage_class }
        trivy      = { storageClass = var.global_storage_class }
      }
    }
  })]
}
