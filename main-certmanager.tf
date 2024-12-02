resource "helm_release" "cert-manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  namespace  = "cert-manager"
  create_namespace = true

  set {
    name = "crds.enabled"
    value = true
  }
  depends_on = [
    helm_release.nfs
  ]
}
resource "kubectl_manifest" "ca" {
  yaml_body = <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned
  namespace: cert-manager
spec:
  selfSigned: {}
EOF
}
resource "kubectl_manifest" "ca-cert" {
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
    name: selfsigned
    kind: ClusterIssuer
    group: cert-manager.io  
EOF
  depends_on = [
    kubectl_manifest.ca
  ]
}
resource "kubectl_manifest" "ca-issuer" {
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

# put ca in trust chain on hosts
/*
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: setup-script
  namespace: kube-system
data:
  setup.sh: |
    echo "$TRUSTED_CERT" > /usr/local/share/ca-certificates/ca.crt && update-ca-certificates && systemctl restart containerd
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  namespace: kube-system
  name: node-custom-setup
  labels:
    k8s-app: node-custom-setup
spec:
  selector:
    matchLabels:
      k8s-app: node-custom-setup
  template:
    metadata:
      labels:
        k8s-app: node-custom-setup
    spec:
      hostPID: true
      hostNetwork: true
      initContainers:
      - name: init-node
        command: ["nsenter"]
        args: ["--mount=/proc/1/ns/mnt", "--", "sh", "-c", "$(SETUP_SCRIPT)"]
        image: debian
        env:
        - name: TRUSTED_CERT
          valueFrom:
            configMapKeyRef:
              name: trusted-ca
              key: ca.crt
        - name: SETUP_SCRIPT
          valueFrom:
            configMapKeyRef:
              name: setup-script
              key: setup.sh
        securityContext:
          privileged: true
      containers:
      - name: wait
        image: k8s.gcr.io/pause:3.1
*/
