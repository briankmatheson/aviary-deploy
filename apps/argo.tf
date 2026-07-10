resource "helm_release" "argo" {
  name             = "argo"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argo"
  create_namespace = true


  values = [<<EOF
redis-ha:
  enabled: false
global:
  domain: argo.local
configs:
  params:
    # TLS terminates at the Envoy Gateway, so the argo-server backend is plain HTTP.
    server.insecure: true
  repositories:
    aviary-frontend:
      url: https://gitea/share/aviary-frontend
      type: git
server:
  # Ingress disabled; routed via the shared Envoy Gateway (see envoy-gateway.tf).
  ingress:
    enabled: false
EOF
  ]
}


resource "kubectl_manifest" "argo" {
  yaml_body = <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: argo
spec:
  destination:
    namespace: default
    server: https://kubernetes
  project: default
  source:
    chart: argo-cd
    repoURL: https://gitea.local/share/argo-helm
    targetRevision: 3.21.0
    helm:
      values: |
        configs:
          secret:
            argocdServerAdminPassword: yow
EOF
  depends_on = [
    helm_release.argo
  ]
}

resource "kubectl_manifest" "aviary-frontend" {
  yaml_body  = <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: aviary-frontend
  namespace: argo
spec:
  destination:
    namespace: default
    server: https://kubernetes.default.svc
  project: default
  source:
    repoURL: https://gitea/share/aviary-frontend
    path: manifests
    targetRevision: main
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF
  depends_on = [helm_release.argo]
}
