provider "helm" {
  kubernetes {
    config_path = "/home/bmath/k8s/u51/kubeconfig.yaml"
  }
}

resource "helm_release" "nginx_ingress" {
  name       = "nginx-ingress-controller"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "nginx-ingress-controller"
  set {
    name  = "service.type"
    value = "ClusterIP"
  }
}
resource "helm_release" "nfs" {
  name       = "csi-driver-nfs"
  repository = "https://raw.githubusercontent.com/kubernetes-csi/csi-driver-nfs/master/charts"
  chart      = "csi-driver-nfs"
  set {
    name  = "storageClass.create"
    value = true
  }
}
resource "helm_release" "gitea" {
  name       = "gitea"
  repository = "https://dl.gitea.com/charts/"
  chart      = "gitea"
  set {
    name  = "service.type"
    value = "ClusterIP"
  }
  depends_on = [
    helm_release.nginx_ingress
  ]
}

