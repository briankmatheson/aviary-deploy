# gitea is a github-like git server that can be self-hosted. There are a wide
# variety of install options which can be gleaned from the chart's values file
# (`helm show values gitea/gitea`). We set a subset here to support:
# * persistence via our standard nfs storage class
# * ssh support via a separate LoadBalancer IP
# * a single bundled Postgres (HA/redundancy intentionally off)
#
# HTTP exposure is NOT handled here: the shared Envoy Gateway terminates TLS and
# routes gitea.local -> gitea-http:3000 (system/envoy-gateway.tf), just like
# harbor. So the chart's own ingress stays disabled and the default ClusterIP
# http service is used as-is. SSH can't ride the HTTP gateway, so it gets its
# own LoadBalancer IP.
resource "helm_release" "gitea" {
  name             = "gitea"
  chart            = "gitea"
  repository       = "https://dl.gitea.io/charts/"
  namespace        = "gitea"
  create_namespace = true

  # yamlencode() guarantees valid, correctly-nested YAML. The previous flat
  # "admin.password: ..." form was parsed by Helm as literal dotted keys (not
  # nesting), so none of these settings actually reached the chart.
  values = [yamlencode({
    global = {
      storageClass = var.global_storage_class
    }
    gitea = {
      admin = {
        password = var.gitea_admin_password
      }
      config = {
        server = {
          ROOT_URL   = "https://gitea.local/"
          SSH_DOMAIN = var.ssh_external_host
        }
      }
    }
    service = {
      ssh = {
        type           = "LoadBalancer"
        loadBalancerIP = var.ssh_load_balancer_ip
        port           = 22
      }
    }
    ingress = {
      enabled = false
    }
    # Bundled single-node Postgres; disable the HA variant to keep one DB.
    postgresql = {
      enabled = var.postgresql_enabled
    }
    "postgresql-ha" = {
      enabled = false
    }
  })]

  depends_on = [
    helm_release.postgres,
  ]
}

# Exposure handled by the shared Envoy Gateway (gitea.local -> gitea-http:3000).
resource "kubectl_manifest" "drone" {
  yaml_body = <<EOF
apiVersion: v1
kind: Service
metadata:
  labels:
    app: drone
  name: drone
  namespace: default
spec:
  externalName: aviary-gateway.envoy-gateway-system.svc.cluster.local
  selector:
    app: drone
  sessionAffinity: None
  type: ExternalName
EOF
  # aviary-gateway (kubectl_manifest.gateway_alias_svc) lives in the system/
  # stack; apply system/ so the ExternalName target resolves.
  depends_on = [
    helm_release.gitea,
  ]
}
