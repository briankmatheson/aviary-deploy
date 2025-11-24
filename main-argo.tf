resource "helm_release" "argo" {
  name       = "argo"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = "argo"
  create_namespace = true


  values = [<<EOF
redis-ha:
  enabled: false
global:
  domain: argo.local
configs:
  params:
    server.insecure: false
  repositories:
    aviary-frontend:
      url: https://gitea/share/aviary-frontend
      type: git
server:
  ingress:
    enabled: true
    ingressClassName: nginx
    annotations:
      cert-manager.io/cluster-issuer: ca-issuer
      nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
      nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
    extraTls:
      - hosts:
        - argo.local
        secretName: argo-tls
EOF
]
  depends_on = [
    helm_release.dashboard,
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
  yaml_body = <<EOF
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
