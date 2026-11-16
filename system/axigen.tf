# Axigen mail server, deployed with AxiHelm (https://axigen.com/go/kubernetes):
# one backend, one SMTP frontend, one proxy frontend (IMAP/POP3/WebMail), the
# cluster manager and a fluentd log collector. WebMail is served at
# mail.<base_domain> by the shared Envoy Gateway (system/envoy-gateway.tf).
#
# Axigen will not start without a license, so the whole file is inert until
# axigen_license_file points at an axigen_lk.bin.
#
# The chart takes the mail domain from the release name; k8sObjectName keeps
# the object names short (axigen-mail-*) whatever the domain is.
#
# Mail protocols stay in-cluster (ClusterIP): axigen-mail-smtp-fe-svc:25,
# -submission-fe-svc:587, -imap-fe-svc:143 and their TLS twins on 465/993/995,
# which present the chart's own generated CA. Setting network.serviceType to
# LoadBalancer would publish every one of them.
#
# Node prerequisite the chart cannot set: every Axigen pod carries a fluent-bit
# sidecar that needs ~9 inotify instances, so nodes want
# fs.inotify.max_user_instances well above the usual 128 (the chart README
# suggests 2048) or the sidecars crash-loop with "Too many open files".

locals {
  axigen_enabled     = var.axigen_license_file != ""
  axigen_namespace   = "${var.ns_prefix}axigen"
  axigen_mail_domain = var.axigen_mail_domain != "" ? var.axigen_mail_domain : var.base_domain
}

resource "kubernetes_namespace" "axigen" {
  count = local.axigen_enabled ? 1 : 0
  metadata {
    name = local.axigen_namespace
  }
}

# The chart refuses to render unless this ConfigMap already exists, and the
# key must be exactly axigen_lk.bin.
resource "kubernetes_config_map" "axigen_license" {
  count = local.axigen_enabled ? 1 : 0
  metadata {
    name      = "axigen-license"
    namespace = kubernetes_namespace.axigen[0].metadata[0].name
  }
  binary_data = {
    "axigen_lk.bin" = filebase64(var.axigen_license_file)
  }
}

# The cluster manager's ServiceAccount is a prerequisite, not part of the
# chart: this is the chart's axiclumgr-resources.yaml (0.13.1, with events).
resource "kubernetes_service_account" "axiclumgr" {
  count = local.axigen_enabled ? 1 : 0
  metadata {
    name      = "axiclumgr"
    namespace = kubernetes_namespace.axigen[0].metadata[0].name
  }
}

resource "kubernetes_role" "axiclumgr" {
  count = local.axigen_enabled ? 1 : 0
  metadata {
    name      = "axiclumgr-role"
    namespace = kubernetes_namespace.axigen[0].metadata[0].name
  }
  rule {
    api_groups = [""]
    resources  = ["pods", "services", "events"]
    verbs      = ["get", "watch", "list"]
  }
  rule {
    api_groups = ["snapshot.storage.k8s.io"]
    resources  = ["volumesnapshots"]
    verbs      = ["get", "create", "delete"]
  }
  rule {
    api_groups = ["apps"]
    resources  = ["statefulsets", "statefulsets/scale"]
    verbs      = ["get", "watch", "list", "patch", "update"]
  }
}

resource "kubernetes_role_binding" "axiclumgr" {
  count = local.axigen_enabled ? 1 : 0
  metadata {
    name      = "axiclumgr-rb"
    namespace = kubernetes_namespace.axigen[0].metadata[0].name
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.axiclumgr[0].metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.axiclumgr[0].metadata[0].name
    namespace = kubernetes_namespace.axigen[0].metadata[0].name
  }
}

resource "helm_release" "axigen" {
  count      = local.axigen_enabled ? 1 : 0
  name       = local.axigen_mail_domain # the chart reads the mail domain from here
  repository = "https://helm.axigen.com"
  chart      = "axigen"
  version    = "0.13.1"
  namespace  = kubernetes_namespace.axigen[0].metadata[0].name
  timeout    = 900

  values = [yamlencode({
    k8sObjectName = "mail"

    server = {
      clusterKey       = var.axigen_cluster_key
      adminPassword    = var.axigen_admin_password
      licenseConfigMap = kubernetes_config_map.axigen_license[0].metadata[0].name
      defaultLanguage  = "en"
      defaultTimeZone  = var.axigen_timezone
      beWorkDirSize    = var.axigen_storage_size
      # The gateway terminates TLS and speaks plain HTTP to its backends, so
      # WebMail needs its port-80 Service (axigen-mail-wm-fe-svc). This also
      # opens 587/143/110, in-cluster only.
      enableNonSSLsvc = true
    }

    persistence = { storageClass = var.global_storage_class }
    network     = { serviceType = "ClusterIP" }
  })]

  depends_on = [
    kubernetes_config_map.axigen_license,
    kubernetes_role_binding.axiclumgr,
  ]
}
