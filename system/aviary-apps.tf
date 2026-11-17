# AviaryApp: what the landing page (aviary-frontend) knows about an app beyond
# its route -- its description, whether it is listed under Apps or System (a
# System entry's link and controls are for admins only), whether it has a page
# to open, and which further namespaces are counted on its tile. One object
# per app, named like the tile (the first label of the app's hostname).
#
# The definition lives here, in the stack that is applied first, with the
# objects for every app of both stacks in one table. An app with no object
# still gets a tile: the page falls back to the route's aviary/group label
# and its built-in list.
resource "kubectl_manifest" "aviaryapp_crd" {
  yaml_body = <<EOF
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: aviaryapps.aviary.xdebbie.org
spec:
  group: aviary.xdebbie.org
  scope: Cluster
  names:
    kind: AviaryApp
    listKind: AviaryAppList
    plural: aviaryapps
    singular: aviaryapp
    shortNames: [avapp]
  versions:
    - name: v1alpha1
      served: true
      storage: true
      additionalPrinterColumns:
        - { name: Group, type: string, jsonPath: .spec.group }
        - { name: Web, type: boolean, jsonPath: .spec.web }
        - { name: Namespaces, type: string, jsonPath: .spec.namespaces }
        - { name: Description, type: string, jsonPath: .spec.description }
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec:
              type: object
              properties:
                description:
                  description: The line under the app's name on the landing page.
                  type: string
                  maxLength: 120
                group:
                  description: Which list the app is under. A system app's link and controls are for admins only.
                  type: string
                  enum: [apps, system]
                web:
                  description: False for an app that is routed but has no page to open; it is listed by name with no link.
                  type: boolean
                namespaces:
                  description: Further namespaces whose usage, workloads and restarts belong to this app's tile, besides the one its route points into.
                  type: array
                  maxItems: 16
                  items:
                    type: string
                    pattern: '^[a-z0-9]([-a-z0-9]*[a-z0-9])?$'
                    maxLength: 63
EOF
}

locals {
  aviary_apps = {
    argo         = { group = "apps", description = "Continuous delivery (Argo CD)" }
    bash         = { group = "system", description = "In-cluster shell" }
    cloudbeaver  = { group = "apps", description = "Database client (CloudBeaver)" }
    "cnpg-ui"    = { group = "system", description = "Postgres clusters (CloudNativePG)" }
    "coredns-ui" = { group = "system", description = "Console for the authoritative DNS" }
    dns          = { group = "system", description = "Authoritative DNS for our domains (port 53)" }
    drone        = { group = "apps", description = "Continuous integration", namespaces = ["${var.ns_prefix}drone-builds"] }
    garage       = { group = "system", description = "Object storage (Garage S3)" }
    gitea        = { group = "apps", description = "Source code management" }
    grafana      = { group = "system", description = "Metrics visualisation and alerting" }
    harbor       = { group = "apps", description = "Container image registry" }
    headlamp     = { group = "system", description = "Kubernetes UI" }
    jitsi        = { group = "apps", description = "Video conferencing" }
    kubeshark    = { group = "system", description = "Live traffic between pods (Kubeshark)" }
    mail         = { group = "apps", description = "Mail (Axigen WebMail)" }
    mattermost   = { group = "apps", description = "Team chat" }
    rustpad      = { group = "apps", description = "Shared text editor" }
    velero       = { group = "system", description = "Backup and restore", web = false }
  }
}

resource "kubectl_manifest" "aviaryapp" {
  for_each = local.aviary_apps
  yaml_body = yamlencode({
    apiVersion = "aviary.xdebbie.org/v1alpha1"
    kind       = "AviaryApp"
    metadata   = { name = each.key }
    spec       = each.value
  })
  depends_on = [kubectl_manifest.aviaryapp_crd]
}
