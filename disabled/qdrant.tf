# DISABLED. To enable: move this file to data/, put the qdrant.local entry
# back into local.vhosts (system/envoy-gateway.tf), apply data/ then system/.
resource "helm_release" "qdrant" {
  name             = "qdrant"
  repository       = "https://qdrant.github.io/qdrant-helm"
  chart            = "qdrant"
  namespace        = "qdrant"
  create_namespace = true
  # Exposure handled by the shared Envoy Gateway (qdrant.local -> qdrant:6333).
}
