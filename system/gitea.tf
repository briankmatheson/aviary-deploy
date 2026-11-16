# gitea is a github-like git server that can be self-hosted. There are a wide
# variety of install options which can be gleaned from the chart's values file
# (`helm show values gitea/gitea`). We set a subset here to support:
# * persistence via var.global_storage_class
# * ssh support via a separate LoadBalancer IP
# * a single bundled Postgres (HA/redundancy intentionally off)
#
# HTTP exposure is NOT handled here: the shared Envoy Gateway terminates TLS and
# routes gitea.<base_domain> -> gitea-http:3000 (system/envoy-gateway.tf), just like
# harbor. So the chart's own ingress stays disabled and the default ClusterIP
# http service is used as-is. SSH can't ride the HTTP gateway, so it gets its
# own LoadBalancer IP.
resource "helm_release" "gitea" {
  name             = "gitea"
  chart            = "gitea"
  repository       = "https://dl.gitea.io/charts/"
  namespace        = "${var.ns_prefix}gitea"
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
          ROOT_URL   = "https://gitea.${var.base_domain}/"
          SSH_DOMAIN = local.ssh_external_host
        }
        # push-to-create: a `git push` to a not-yet-existing repo creates it,
        # so repos can be seeded over SSH without an API token first.
        repository = {
          ENABLE_PUSH_CREATE_USER = true
          ENABLE_PUSH_CREATE_ORG  = true
        }
        # No self-service signup: Gitea gates the aviary landing page's
        # cluster-admin actions, so accounts are admin-created only.
        service = {
          DISABLE_REGISTRATION     = true
          SHOW_REGISTRATION_BUTTON = false
        }
        # Webhook delivery targets (e.g. Drone) live on the private mesh, which
        # gitea's anti-SSRF guard blocks by default ("webhook can only call
        # allowed HTTP servers"). Allow private ranges so push events reach CI.
        webhook = {
          # Scope webhook delivery to the mesh range only. Drone and every other
          # in-mesh webhook target live in 10.23.0.0/16; tighter than the broad
          # RFC1918 "private" set.
          ALLOWED_HOST_LIST = "10.23.0.0/16"
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
    # Webhooks go to https://drone.<base_domain>, whose cert is signed by the
    # cluster's internal CA. Trust it via the trust-manager bundle (public CAs
    # plus the XDebbie step-ca root), or deliveries fail with x509 errors.
    deployment = {
      env = [{
        name  = "SSL_CERT_FILE"
        value = "/etc/gitea-trust/ca-bundle.pem"
      }]
    }
    extraVolumes = [{
      name      = "xdebbie-trust"
      configMap = { name = "xdebbie-ca-bundle" }
    }]
    extraContainerVolumeMounts = [{
      name      = "xdebbie-trust"
      mountPath = "/etc/gitea-trust"
      readOnly  = true
    }]
    # RWO volume: a RollingUpdate deadlocks (the new pod cannot attach the
    # PVC the old one still holds).
    strategy = {
      type = "Recreate"
    }
    # Bundled single-node Postgres and Valkey; the HA/cluster variants the
    # chart defaults to need more nodes than a small cluster has.
    postgresql = {
      enabled = var.postgresql_enabled
    }
    "postgresql-ha" = {
      enabled = false
    }
    valkey = {
      enabled = true
    }
    "valkey-cluster" = {
      enabled = false
    }
  })]

  # The pod mounts the bundle's ConfigMap and cannot start without it.
  depends_on = [kubectl_manifest.ca_bundle]
}

# Exposure handled by the shared Envoy Gateway (gitea.<base_domain> -> gitea-http:3000).
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
