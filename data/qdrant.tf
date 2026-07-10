resource "helm_release" "qdrant" {
  name             = "qdrant"
  repository       = "https://qdrant.github.io/qdrant-helm"
  chart            = "qdrant"
  namespace        = "qdrant"
  create_namespace = true
  # Exposure handled by the shared Envoy Gateway (qdrant.local -> qdrant:6333).
}
