resource "kubernetes_manifest" "l2-advertisements" {
  manifest = {    "apiVersion" = "metallb.io/v1beta1"
    "kind"       = "L2Advertisement"
    "metadata"   = {
      "name"      = "l2"
      "namespace" = "metallb-system"
    }
    "spec"       = {
      "ipAddressPools" = [ "ssh-ip", "ing-ip" ]
    }
  }
}
resource "kubernetes_manifest" "ing-ip" {
  manifest = {    "apiVersion" = "metallb.io/v1beta1"
    "kind"       = "IPAddressPool"
    "metadata"   = {
      "name"      = "ing-ip"
      "namespace" = "metallb-system"
    }
    "spec"        = {
      "addresses" = [
	"10.23.99.4/32",
	"10.23.99.5/32",
	"10.23.99.6/32",
	"10.23.99.7/32"
      ]
    }
  }
}


resource "helm_release" "ingress-nginx" {
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  namespace  = "ingress-nginx"
  create_namespace = true
  set {
    name  = "service.type"
    value = "LoadBalancer"
  }
  set {
    name = "service.externalIPs"
    value = "ing-ip"
  }
  set {
    name = "controller.service.externalTrafficPolicy"
    value = "Local"
  }
  depends_on = [
    helm_release.cert-manager,
    kubectl_manifest.ca-issuer
  ]
}


resource "helm_release" "nfs" {
  name       = "csi-driver-nfs"
  repository = "https://raw.githubusercontent.com/kubernetes-csi/csi-driver-nfs/master/charts"
  chart      = "csi-driver-nfs"
  namespace  = "kube-system"
}
resource "kubernetes_storage_class" "standard" {
  metadata {
    name = "standard"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }
  storage_provisioner = "nfs.csi.k8s.io"
  reclaim_policy      = "Delete"
  volume_binding_mode = "WaitForFirstConsumer"
  parameters = {
    server = "10.23.99.1"
    share = "/export/fast-nfs"
  }
  mount_options = ["nfsvers=4.2"]
  depends_on = [
    helm_release.nfs
  ]
}

resource "helm_release" "dashboard" {
  name = "kubernetes-dashboard"
  repository = "https://kubernetes.github.io/dashboard/"
  chart = "kubernetes-dashboard"
  namespace = "kube-system"
  set {
    name = "kong.env.proxy_listen"
    value = "0.0.0.0:8443 http2 ssl"
  }
  set {
    name = "kong.env.admin_listen"
    value = "0.0.0.0:8443 http2 ssl"
  }
  set {
    name = "kong.env.status_listen"
    value = "0.0.0.0:8443 http2 ssl"
  }
  depends_on = [
    helm_release.nfs
  ]
}
resource "kubernetes_ingress_v1" "dashboard" {
  wait_for_load_balancer = true
  metadata {
    name = "kubernetes-dashboard" 
    namespace = "kube-system"
    annotations = {
      "kubernetes.io/ingress.class" = "nginx"
      "cert-manager.io/cluster-issuer" = "ca-issuer"
    }
  }
  spec {
    ingress_class_name = "nginx"
    rule {
      host = "kubernetes-dashboard.local"
      http {
        path {
          path = "/"
          backend {
            service {
	      name = "kubernetes-dashboard-web"
              port {
		number = 80
	      }
	    }
          }
        }
      }
    }
    tls {
      secret_name = "kubernetes-dashboard-tls"
      hosts = [ "kubernetes-dashboard.local" ]
    }
  }
  depends_on = [
    helm_release.dashboard,
    helm_release.ingress-nginx
  ]
}
