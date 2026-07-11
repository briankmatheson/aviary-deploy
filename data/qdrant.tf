# Qdrant is disabled for now. Re-enable by uncommenting this resource and
# running `make plan && make apply`. Note the shared Envoy Gateway still has a
# qdrant.local route (system/envoy-gateway.tf); it simply won't resolve until
# this release is applied again.
# resource "helm_release" "qdrant" {
#   name             = "qdrant"
#   repository       = "https://qdrant.github.io/qdrant-helm"
#   chart            = "qdrant"
#   namespace        = "qdrant"
#   create_namespace = true
#   # Exposure handled by the shared Envoy Gateway (qdrant.local -> qdrant:6333).
# }
