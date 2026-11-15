/* CloudNativePG operator. Apps declare their own cnpg `Cluster` resources;
   the operator runs the Postgres instances, with failover and backups. */
resource "helm_release" "cnpg" {
  name             = "cnpg"
  repository       = "https://cloudnative-pg.github.io/charts"
  chart            = "cloudnative-pg"
  namespace        = var.cnpg_namespace
  create_namespace = true
  # No version pin: tracks the chart's latest. Set `version` to freeze it.
}
