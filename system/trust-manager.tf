# trust-manager distributes a CA bundle -- the public CA set plus the cluster's
# own internal root (the "XDebbie Simple CA Root" behind internal-acme) -- as a
# `ca-bundle.pem` ConfigMap in every namespace. Any pod can mount that ConfigMap
# to trust internal TLS (gitea, harbor, ...), which is how drone stops hitting
# "x509: certificate signed by unknown authority" talking to gitea.

resource "helm_release" "trust_manager" {
  name       = "trust-manager"
  repository = "https://charts.jetstack.io"
  chart      = "trust-manager"
  namespace  = "cert-manager"
  # trust-manager reads Bundle sources (ConfigMaps/Secrets) from its own
  # namespace by default (cert-manager), which is where xdebbie-root-ca lives.
}

# The internal-acme ClusterIssuer carries the root in spec.acme.caBundle; copy it
# into a ConfigMap in the trust namespace so the Bundle can source it.
data "kubernetes_resource" "internal_acme" {
  api_version = "cert-manager.io/v1"
  kind        = "ClusterIssuer"
  metadata {
    name = var.cluster_issuer
  }
}

resource "kubernetes_config_map" "xdebbie_root" {
  metadata {
    name      = "xdebbie-root-ca"
    namespace = "cert-manager"
  }
  data = {
    "root.pem" = base64decode(data.kubernetes_resource.internal_acme.object.spec.acme.caBundle)
  }
}

resource "kubectl_manifest" "ca_bundle" {
  yaml_body  = <<-EOF
    apiVersion: trust.cert-manager.io/v1alpha1
    kind: Bundle
    metadata:
      name: xdebbie-ca-bundle
    spec:
      sources:
        - useDefaultCAs: true
        - configMap:
            name: ${kubernetes_config_map.xdebbie_root.metadata[0].name}
            key: root.pem
      target:
        configMap:
          key: ca-bundle.pem
        namespaceSelector: {}
  EOF
  depends_on = [helm_release.trust_manager, kubernetes_config_map.xdebbie_root]
}
