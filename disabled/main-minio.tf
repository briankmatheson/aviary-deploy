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
  namespace: minio
stringData:
  config.env: |-
    export MINIO_ROOT_USER=storage-user
    export MINIO_ROOT_PASSWORD=storage-password
    export MINIO_STORAGE_CLASS_STANDARD="standard"
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
  CONSOLE_ACCESS_KEY: c3RvcmFnZS11c2VyCg==
  CONSOLE_SECRET_KEY: c3RvcmFnZS1wYXNzd29yZAo=
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

resource "kubectl_manifest" "minio_backup_user" {
  yaml_body = <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: backup-user
  namespace: default
stringData:
  CONSOLE_ACCESS_KEY: backup-user
  CONSOLE_SECRET_KEY: backup-password
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
  name: minio0
  namespace: minio
spec:
  configuration:
    name: storage-configuration
  features:
    bucketDNS: false
  image: quay.io/minio/minio:RELEASE.2024-10-02T17-50-41Z
  imagePullSecret: {}
  mountPath: /export
  podManagementPolicy: Parallel
  pools:
    - name: pool-0
      servers: 4
      volumesPerServer: 4
      affinity:
        nodeAffinity: {}
        podAffinity: {}
        podAntiAffinity: {}
      containerSecurityContext:
        allowPrivilegeEscalation: false
        capabilities:
          drop: [ "ALL" ]
        runAsGroup: 1000
        runAsNonRoot: true
        runAsUser: 1000
        seccompProfile:
          type: RuntimeDefault
      securityContext:
        fsGroup: 1000
        fsGroupChangePolicy: OnRootMismatch
        runAsGroup: 1000
        runAsNonRoot: true
        runAsUser: 1000
      volumeClaimTemplate:
        apiVersion: v1
        kind: PersistentVolumeClaim
        spec:
          accessModes:
            - ReadWriteOnce
          resources:
            requests:
              storage: 1Gi
          storageClassName: standard
  requestAutoCert: true
  users:
    - name: storage-user
    - name: backup-user
  readinessProbe:
    httpGet:
      path: /minio/health/ready
      port: 9000
  livenessProbe:
    httpGet:
        path: /minio/health/live
        port: 9000
EOF
  depends_on = [
    helm_release.minio,
    kubectl_manifest.minio_backup_user
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
      host = "minio.local"
      http {
        path {
          path = "/"
          backend {
            service {
              name = "minio"
              port {
                number = 9443
              }
            }
          }
	}
      }
    }
    rule {
      host = "minio-console.local"
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
    rule {
      host = "minio"
      http {
        path {
          path = "/"
          backend {
            service {
	      name = "minio"
              port {
                number = 443
              }
            }
          }
        }
      }
    }
    tls {
      secret_name = "minio-tls"
      hosts = [ "minio.local", "minio" ]
    }
  }
  depends_on = [
    helm_release.minio,
  ]
}

resource "minio_accesskey" "backup-user" {
  user               = "backup-user"
  access_key         = "backup-user" # Must be 8-20 characters
  secret_key         = "backup-password" # Must be at least 8 characters
  secret_key_version = "v1"               # Version identifier for change detection
  status            = "enabled"
}

resource "minio_s3_bucket" "velero-backups" {
  bucket         = "velero-backups"
  acl            = "private"
  object_locking = true
}

resource "kubectl_manifest" "minio-velero-alias" {
  yaml_body = <<EOF
apiVersion: v1
kind: Service
metadata:
  name: minio
  namespace: velero
spec:
  externalName: ingress-nginx-controller.ingress-nginx.svc.cluster.local
  sessionAffinity: None
  type: ExternalName
EOF
  depends_on = [
    helm_release.minio,
  ]
}
