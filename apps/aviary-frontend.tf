resource "kubectl_manifest" "aviary-frontend-deployment" {
  yaml_body = <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: aviary-frontend
  name: aviary-frontend
  namespace: kube-system
spec:
  progressDeadlineSeconds: 600
  replicas: 1
  revisionHistoryLimit: 10
  selector:
    matchLabels:
      app: aviary-frontend
  strategy:
    rollingUpdate:
      maxSurge: 25%
      maxUnavailable: 25%
    type: RollingUpdate
  template:
    metadata:
      creationTimestamp: null
      labels:
        app: aviary-frontend
    spec:
      containers:
      - image: briankmatheson/aviary-frontend
        imagePullPolicy: Always
        name: aviary-frontend
        resources: {}
        terminationMessagePath: /dev/termination-log
        terminationMessagePolicy: File
      dnsPolicy: ClusterFirst
      restartPolicy: Always
      schedulerName: default-scheduler
      securityContext: {}
      terminationGracePeriodSeconds: 30
EOF
}

resource "kubectl_manifest" "aviary-frontend-svc" {
  yaml_body = <<EOF
apiVersion: v1
kind: Service
metadata:
  labels:
    app: aviary-frontend
  name: aviary-frontend
  namespace: kube-system
spec:
  internalTrafficPolicy: Cluster
  ipFamilies:
  - IPv4
  ipFamilyPolicy: SingleStack
  ports:
  - port: 8086
    protocol: TCP
    targetPort: 8086
  selector:
    app: aviary-frontend
  sessionAffinity: None
  type: ClusterIP
EOF
}

# Exposure handled by the shared Envoy Gateway (aviary.local -> aviary:8086).
