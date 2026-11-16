# Mattermost (team edition): a self-hosted, Slack-like chat server, served at
# mattermost.<base_domain> by the shared Envoy Gateway (system/envoy-gateway.tf),
# exactly like gitea and harbor -- the chart's own ingress stays off and the
# default ClusterIP Service (mattermost-team-edition:8065) is routed to.
#
# The database is a CloudNativePG Postgres Cluster in the same namespace, not the
# chart's bundled MySQL (deprecated in Mattermost 12). The app DB owner password
# is pre-seeded as a Secret so the externalConnectionString and the DB credential
# stay in lockstep (cnpg adopts an existing <cluster>-app secret instead of
# generating its own).

resource "kubernetes_namespace" "mattermost" {
  metadata {
    name = "${var.ns_prefix}mattermost"
  }
}

resource "kubernetes_secret" "mattermost_db" {
  metadata {
    name      = "mattermost-pg-app"
    namespace = kubernetes_namespace.mattermost.metadata[0].name
  }
  type = "kubernetes.io/basic-auth"
  data = {
    username = "mattermost"
    password = var.mattermost_db_password
  }
}

# Single-instance Postgres (HA intentionally off, like gitea's bundled DB). The
# operator publishes a mattermost-pg-rw Service for read-write traffic.
resource "kubectl_manifest" "mattermost_pg" {
  yaml_body  = <<-EOF
    apiVersion: postgresql.cnpg.io/v1
    kind: Cluster
    metadata:
      name: mattermost-pg
      namespace: ${kubernetes_namespace.mattermost.metadata[0].name}
    spec:
      instances: 1
      storage:
        size: 10Gi
        storageClass: ${var.global_storage_class}
      bootstrap:
        initdb:
          database: mattermost
          owner: mattermost
          secret:
            name: ${kubernetes_secret.mattermost_db.metadata[0].name}
  EOF
  depends_on = [kubernetes_secret.mattermost_db]
}

resource "helm_release" "mattermost" {
  name       = "mattermost"
  repository = "https://helm.mattermost.com"
  chart      = "mattermost-team-edition"
  namespace  = kubernetes_namespace.mattermost.metadata[0].name
  timeout    = 600 # mattermost crash-loops until cnpg finishes bootstrapping

  values = [yamlencode({
    # Exposure is the shared gateway's job; keep the chart's ingress/route off.
    ingress = { enabled = false }
    route   = { enabled = false }

    # Postgres from the cnpg Cluster above, not the chart's deprecated MySQL.
    mysql = { enabled = false }
    externalDB = {
      enabled                  = true
      externalDriverType       = "postgres"
      externalConnectionString = "mattermost:${var.mattermost_db_password}@mattermost-pg-rw.${kubernetes_namespace.mattermost.metadata[0].name}.svc.cluster.local:5432/mattermost?sslmode=disable&connect_timeout=10"
    }

    persistence = {
      data    = { enabled = true, size = "10Gi", storageClass = var.global_storage_class }
      plugins = { enabled = true, size = "1Gi", storageClass = var.global_storage_class }
    }

    # Mattermost is strict about SiteURL; it must match the gateway vhost.
    config = {
      MM_SERVICESETTINGS_SITEURL = "https://mattermost.${var.base_domain}"
    }
  })]

  depends_on = [kubectl_manifest.mattermost_pg]
}
