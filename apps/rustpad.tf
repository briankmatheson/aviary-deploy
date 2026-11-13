# Rustpad: the TrueCharts OCI chart (tccr.io/truecharts/rustpad) is gone, so
# deploy the upstream image directly. SQLITE_URI makes documents survive
# restarts (rustpad is in-memory otherwise).
resource "kubernetes_namespace" "rustpad" {
  metadata {
    name = var.rustpad_namespace
  }
}

resource "kubernetes_persistent_volume_claim" "rustpad" {
  metadata {
    name      = "rustpad-data"
    namespace = kubernetes_namespace.rustpad.metadata[0].name
  }
  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = var.global_storage_class
    resources {
      requests = {
        storage = "${var.rustpad_pvc_size}Gi"
      }
    }
  }
  wait_until_bound = false
}

# kubectl_manifest rather than kubernetes_deployment: hashicorp/kubernetes
# 2.38 + tofu 1.13 trips "Unexpected Identity Change" on re-read of the latter.
resource "kubectl_manifest" "rustpad" {
  yaml_body = <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rustpad
  namespace: ${kubernetes_namespace.rustpad.metadata[0].name}
  labels:
    app: rustpad
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: rustpad
  template:
    metadata:
      labels:
        app: rustpad
    spec:
      securityContext:
        fsGroup: 1000
      containers:
        - name: rustpad
          image: ekzhang/rustpad:latest
          ports:
            - containerPort: 3030
          env:
            - name: SQLITE_URI
              value: sqlite:///data/rustpad.db
          volumeMounts:
            - name: data
              mountPath: /data
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: ${kubernetes_persistent_volume_claim.rustpad.metadata[0].name}
EOF
}

resource "kubernetes_service" "rustpad" {
  metadata {
    name      = "rustpad"
    namespace = kubernetes_namespace.rustpad.metadata[0].name
  }
  spec {
    selector = { app = "rustpad" }
    port {
      port        = 3030
      target_port = 3030
    }
  }
}
# Exposure handled by the shared Envoy Gateway (rustpad.<base_domain> -> rustpad:3030).
