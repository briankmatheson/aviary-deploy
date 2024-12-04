resource "kubernetes_namespace" "mattermost" {
  metadata {
     name = "mattermost"
  }
}

/*
resource "kubectl_manifest" "mm-pgdb" {
  force_new = true
  validate_schema = false
  
  yaml_body = <<EOF
kind: "postgresql"
apiVersion: "acid.zalan.do/v1"
metadata:
  name: "mm-pgdb"
  namespace: "mattermost"
  labels:
    team: mm
spec:
  teamId: "mm"
  postgresql:
    version: "16"
  numberOfInstances: 1
  maintenanceWindows:
  volume:
    size: "10Gi"
  users:
    mm: [ "createdb" ]
  databases:
    mm: mm
  resources:
    requests:
      cpu: 100m
      memory: 100Mi
    limits:
      cpu: 500m
      memory: 500Mi
  EOF
  depends_on = [
    kubernetes_namespace.mattermost,
    helm_release.postgres
  ]
}
resource "kubernetes_manifest" "mm-pgdb" {
  manifest = {
    "kind" = "postgresql"
    "apiVersion" = "acid.zalan.do/v1"
    "metadata" = {
      "name" = "mm-pgdb"
      "namespace" = "mattermost"
      "labels" = {
	"team" = "mm"
      }
    }
    "spec" = {
      "teamId" = "mm"
      "postgresql" = {
	"version" = "16"
      }
      "numberOfInstances" = 1
      "volume" = {
	  "size" = "10Gi"
      }
      "resources" = {
	"requests" = {
	  "cpu" = "100m"
	  "memory" = "100Mi"
	}
        "limits" = {
	  "cpu" = "500m"
	  "memory" = "500Mi"
	}
      }
    }
  }
  depends_on = [
    kubernetes_namespace.mattermost,
    helm_release.postgres
  ]
}
resource "helm_release" "mattermost" {
  name       = "mattermost"
  repository = "https://helm.mattermost.com"
  chart      = "mattermost-team-edition"
  namespace  = "mattermost"
  set {
    name = "mysql.enabled"
    value = true
  }
  set {
    name = "externalDB.enabled"
    value = false
  }
  # set {
  #   name = "externalDB.externalDriverType"
  #   value = "postgres"
  # }
  # set {
  #   name = "externalDB.externalConnectionString"
  #   value = "mm:rrrrrrrr@mm-pgdb:5432/mm?sslmode=disable&connect_timeout=10"
  # }
  
  depends_on = [
    helm_release.nfs
  ]
}
resource "kubectl_manifest" "mattermost" {
  server_side_apply = true
  yaml_body = <<EOF
apiVersion: installation.mattermost.com/v1beta1
kind: Mattermost
metadata:
  name: mattermost
  namespace: mattermost
spec:
  ingress:
    enabled: true
    host: mattermost.local
    ingressAnnotations:
      kubernetes.io/ingress.class: nginx
EOF
  depends_on = [
    helm_release.mattermost,
    helm_release.ingress-nginx
  ]
}
*/

resource "helm_release" "focalboard" {
  name       = "focalboard"
  repository = "https://helm.mattermost.com"
  chart      = "focalboard"
  namespace  = "mattermost"

  set {
    name = "ingress.enabled"
    value = true
  }
  set {
    name = "ingress.hosts[0].host"
    value = "focalboard.local"
  }
  set {
    name = "ingress.hosts[0].paths[0].path"
    value = "/"
  }
  set {
    name = "persistence.enabled"
    value = true
  }
  set {
    name = "persistence.accessMode"
    value = "ReadWriteMany"
  }
  set {
    name = "persistence.size"
    value = "8Gi"
  }
  depends_on = [
    helm_release.ingress-nginx
  ]
}
