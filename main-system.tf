resource "kubernetes_manifest" "ing-ip" {
  manifest = {
    "apiVersion" = "cilium.io/v2alpha1"
    "kind" = "CiliumLoadBalancerIPPool"
    "metadata" = {
      "name" = "ing-ip"
      "spec" = {
        "blocks" = var.metallb_ip_address_pool
      }
    }
  }
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
    server = var.nfs_server
    share  = var.nfs_share
  }
  mount_options = ["nfsvers=4.2"]
}

# in case we're running under kind we can uncomment this:
# resource "kubernetes_storage_class" "standard" {
#   storage_provisioner = "rancher.io/local-path"
#   metadata {
#     name = "standard"
#     annotations = {
#       "storageclass.kubernetes.io/is-default-class" = "true"
#     }
#   }
# }

resource "helm_release" "cert-manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  namespace  = "cert-manager"
  create_namespace = true

  set = [{
    name = "crds.enabled"
    value = true
  }]
}

resource "kubectl_manifest" "ca" {
  force_new = false
  validate_schema = false
  yaml_body = <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned-ca
spec:
  selfSigned: {}
EOF
  depends_on = [
    helm_release.cert-manager
  ]
}
resource "kubectl_manifest" "ca-cert" {
  force_new = false
  yaml_body = <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: ca
  namespace: cert-manager
spec:
  isCA: true
  commonName: ca
  secretName: ca-secret
  privateKey:
    algorithm: ECDSA
    size: 256
  issuerRef:
    name: selfsigned-ca
    kind: ClusterIssuer
    group: cert-manager.io  
EOF
  depends_on = [
    kubectl_manifest.ca
  ]
}
resource "kubectl_manifest" "ca-issuer" {
  force_new = false
  yaml_body = <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: ca-issuer
  namespace: cert-manager
spec:
  ca:
    secretName: ca-secret
EOF
  depends_on = [
    kubectl_manifest.ca-cert
  ]
}

resource "helm_release" "ingress-nginx" {
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  namespace  = "ingress-nginx"
  create_namespace = true
  set = [
    {
      name  = "service.type"
      value = "LoadBalancer"
    },
    {
      name = "service.externalIPs"
      value = var.ingress_nginx_external_ip
    },
    {
      name = "controller.service.externalTrafficPolicy"
      value = "Local"
    }
  ]
}

/*
resource "kubernetes_ingress_class_v1" "nginx" {
  metadata {
    name = "nginx"
  }

  spec {
    controller = "k8s.io/ingress-nginx"
    parameters {
      api_group = "k8s.example.com"
      kind      = "IngressParameters"
      name      = "external-lb"
    }
  }
}
*/

resource "helm_release" "dashboard" {
  name = "kubernetes-dashboard"
  repository = "https://kubernetes.github.io/dashboard/"
  chart = "kubernetes-dashboard"
  namespace = "kube-system"
  create_namespace = true
  set = [
    {
      name = "kong.env.proxy_listen"
      value = "0.0.0.0:8443 http2 ssl"
    },
    {
      name = "kong.env.admin_listen"
      value = "0.0.0.0:8443 http2 ssl"
    },
    {
      name = "kong.env.status_listen"
      value = "0.0.0.0:8443 http2 ssl"
    },
    {
      name = "kong.enabled"
      value = false
    }
  ]
}
resource "kubernetes_ingress_v1" "dashboard" {
  metadata {
    name = "kubernetes-dashboard" 
    namespace = "kube-system"
    annotations = {
      "kubernetes.io/ingress.class" = "nginx"
      "cert-manager.io/cluster-issuer" = "ca-issuer"
      "nginx.ingress.kubernetes.io/backend-protocol" = "HTTPS"
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
	      name = "kubernetes-dashboard-kong-proxy"
              port {
		number = 443
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
