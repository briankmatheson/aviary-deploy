resource "helm_release" "minio" {
  name       = "minio"
  repository = "https://operator.min.io"
  chart      = "operator"
  namespace  = var.minio_namespace
  create_namespace = true

  depends_on = [
    helm_release.dashboard,
  ]
}
resource "kubectl_manifest" "minio-storage" {
  yaml_body = <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: storage-configuration
  namespace: ${var.minio_namespace}
stringData:
  config.env: |-
    export MINIO_ROOT_USER="${var.minio_root_user}"
    export MINIO_ROOT_PASSWORD="${var.minio_root_password}"
    export MINIO_STORAGE_CLASS_STANDARD="EC:2"
    export MINIO_BROWSER="on"
type: Opaque
EOF
  depends_on = [
    helm_release.minio,
  ]
}
resource "kubectl_manifest" "minio-keys" {
  yaml_body = <<EOF
apiVersion: v1
data:
  CONSOLE_ACCESS_KEY: Y29uc29sZQ==
  CONSOLE_SECRET_KEY: Y29uc29sZTEyMw==
kind: Secret
metadata:
  name: storage-user
  namespace: minio
type: Opaque
EOF
  depends_on = [
    helm_release.minio,
  ]
}
resource "kubectl_manifest" "minio" {
  yaml_body = <<EOF
apiVersion: minio.min.io/v2
kind: Tenant
metadata:
  annotations:
    prometheus.io/path: /minio/v2/metrics/cluster
    prometheus.io/port: "9000"
    prometheus.io/scrape: "true"
  labels:
    app: minio
  name: minio0
  namespace: minio
spec:
  certConfig: {}
  configuration:
    name: storage-configuration
  env: []
  externalCaCertSecret: []
  externalCertSecret: []
  externalClientCertSecrets: []
  features:
    bucketDNS: false
    domains: {}
  image: quay.io/minio/minio:RELEASE.2024-10-02T17-50-41Z
  imagePullSecret: {}
  mountPath: /export
  podManagementPolicy: Parallel
  pools:
  - affinity:
      nodeAffinity: {}
      podAffinity: {}
      podAntiAffinity: {}
    containerSecurityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop:
        - ALL
      runAsGroup: 1000
      runAsNonRoot: true
      runAsUser: 1000
      seccompProfile:
        type: RuntimeDefault
    name: pool-0
    nodeSelector: {}
    resources: {}
    securityContext:
      fsGroup: 1000
      fsGroupChangePolicy: OnRootMismatch
      runAsGroup: 1000
      runAsNonRoot: true
      runAsUser: 1000
    servers: 4
    tolerations: []
    topologySpreadConstraints: []
    volumeClaimTemplate:
      apiVersion: v1
      kind: persistentvolumeclaims
      metadata: {}
      spec:
        accessModes:
        - ReadWriteOnce
        resources:
          requests:
            storage: 1Gi
        storageClassName: standard
      status: {}
    volumesPerServer: 4
  priorityClassName: ""
  requestAutoCert: true
  serviceAccountName: ""
  serviceMetadata:
    consoleServiceAnnotations: {}
    consoleServiceLabels: {}
    minioServiceAnnotations: {}
    minioServiceLabels: {}
  subPath: ""
  users:
  - name: storage-user
EOF
  depends_on = [
    helm_release.minio,
  ]
}
resource "kubernetes_ingress_v1" "minio" {
  metadata {
    name = "minio"
    namespace = var.minio_namespace
    annotations = {
      "kubernetes.io/ingress.class" = var.minio_ingress_class
      "cert-manager.io/cluster-issuer" =  var.minio_cluster_issuer
      "nginx.ingress.kubernetes.io/backend-protocol" = "HTTPS"
      "nginx.ingress.kubernetes.io/client-max-body-size" = "1024g"
      "nginx.ingress.kubernetes.io/proxy-body-size" = "1024g"
    }
  }
  spec {
    ingress_class_name = var.minio_ingress_class
    rule {
      host = var.minio_host
      http {
        path {
          path = "/"
          backend {
            service {
              name = "minio0-console"
              port {
                number = 9443
              }
            }
          }
        }
      }
    }
    tls {
      secret_name = var.minio_tls_secret_name
      hosts = [ "minio.local", "minio" ]
    }
  }
  depends_on = [
    helm_release.minio,
  ]
}

resource "minio_s3_bucket" "velero-backups" {
  bucket         = var.velero_backup_storage_bucket
  acl            = "private"
  object_locking = true
}

resource "kubectl_manifest" "minio-alias" {
  yaml_body = <<EOF
apiVersion: v1
kind: Service
metadata:
  labels:
    app: minio
  name: minio
  namespace: drone
spec:
  externalName: minio.minio.svc.cluster.local
  selector:
    app: minio
  sessionAffinity: None
  type: ExternalName
EOF
  depends_on = [
    helm_release.minio,
  ]
}
