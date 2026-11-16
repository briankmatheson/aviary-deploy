# Ollama on the cluster's GPU node(s): serves models over its own API and an
# OpenAI-compatible one (/v1). The landing page's chat window talks to it.
# Off unless ollama_enabled; it needs a node labelled nvidia.com/gpu.present
# with the NVIDIA device plugin running, and takes one whole GPU.
#
# Models are kept on the node's own disk (hostPath), so they survive the pod.
# Pull one after the first apply:
#   kubectl -n <ns_prefix>ollama exec deploy/ollama -- ollama pull llama3

locals {
  ollama_namespace = "${var.ns_prefix}ollama"
  ollama_url       = "http://ollama.${local.ollama_namespace}.svc.cluster.local:11434/v1"
  # What the landing page's chat window talks to: an explicit aviary_chat_url,
  # else this Ollama when it is enabled, else nothing (no chat window).
  aviary_chat_url = var.aviary_chat_url != "" ? var.aviary_chat_url : (var.ollama_enabled ? local.ollama_url : "")
}

resource "kubernetes_namespace" "ollama" {
  count = var.ollama_enabled ? 1 : 0
  metadata {
    name = local.ollama_namespace
  }
}

resource "kubectl_manifest" "ollama" {
  count      = var.ollama_enabled ? 1 : 0
  yaml_body  = <<-EOF
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: ollama
      namespace: ${local.ollama_namespace}
      labels:
        app: ollama
    spec:
      replicas: 1
      strategy:
        type: Recreate
      selector:
        matchLabels:
          app: ollama
      template:
        metadata:
          labels:
            app: ollama
        spec:
          nodeSelector:
            nvidia.com/gpu.present: "true"
          tolerations:
            - key: nvidia.com/gpu
              operator: Exists
              effect: NoSchedule
          containers:
            - name: ollama
              image: ${var.ollama_image}
              ports:
                - containerPort: 11434
              env:
                - name: OLLAMA_HOST
                  value: "0.0.0.0:11434"
                - name: OLLAMA_KEEP_ALIVE
                  value: "24h"
              readinessProbe:
                httpGet:
                  path: /api/version
                  port: 11434
              resources:
                requests:
                  cpu: "2"
                  memory: 8Gi
                limits:
                  nvidia.com/gpu: 1
              volumeMounts:
                - name: models
                  mountPath: /root/.ollama
          volumes:
            - name: models
              hostPath:
                path: /var/lib/ollama
                type: DirectoryOrCreate
  EOF
  depends_on = [kubernetes_namespace.ollama]
}

resource "kubernetes_service" "ollama" {
  count = var.ollama_enabled ? 1 : 0
  metadata {
    name      = "ollama"
    namespace = local.ollama_namespace
  }
  spec {
    selector = { app = "ollama" }
    port {
      port        = 11434
      target_port = 11434
    }
  }
  depends_on = [kubernetes_namespace.ollama]
}
