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

# AviaryConfig: the landing page's page-wide settings, in one object named
# "aviary". What it leaves out, the page takes from its environment. The page
# writes the model chosen in its whiteboard, and its locks, to the
# object's status, which this stack does not manage.
resource "kubectl_manifest" "aviaryconfig_crd" {
  yaml_body = <<EOF
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: aviaryconfigs.aviary.xdebbie.org
spec:
  group: aviary.xdebbie.org
  scope: Cluster
  names:
    kind: AviaryConfig
    listKind: AviaryConfigList
    plural: aviaryconfigs
    singular: aviaryconfig
    shortNames: [avcfg]
  versions:
    - name: v1alpha1
      served: true
      storage: true
      subresources:
        status: {}
      additionalPrinterColumns:
        - { name: Idle, type: integer, jsonPath: .spec.session.minutes, description: minutes a sign-in lasts with nothing done }
        - { name: Max, type: integer, jsonPath: .spec.session.maxMinutes, description: minutes a sign-in lasts at most }
        - { name: Admin-Team, type: string, jsonPath: .spec.admin.team }
        - { name: Max-Pods, type: integer, jsonPath: .spec.scale.maxPods }
        - { name: Model, type: string, jsonPath: .status.chat.model }
        - { name: System, type: boolean, jsonPath: .status.locks.system.locked, description: System locked }
        - { name: Apps, type: boolean, jsonPath: .status.locks.apps.locked, description: Apps locked }
        - { name: Whiteboard, type: boolean, jsonPath: .status.locks.whiteboard.locked, description: whiteboard locked }
      schema:
        openAPIV3Schema:
          type: object
          x-kubernetes-validations:
            - rule: self.metadata.name == 'aviary'
              message: there is one AviaryConfig, and it is named "aviary"
          properties:
            spec:
              type: object
              properties:
                session:
                  type: object
                  properties:
                    minutes:
                      description: The idle timer. A sign-in to the landing page runs out after this many minutes with no activity (clicks, keys, actions; not the page's background polling), then goes back through Gitea.
                      type: integer
                      minimum: 1
                      maximum: 1440
                    maxMinutes:
                      description: The most a sign-in lasts from signing in, however active. Gitea cannot tell the page that someone logged out or stopped being an administrator, so this is the longest that can take to show.
                      type: integer
                      minimum: 5
                      maximum: 10080
                admin:
                  type: object
                  properties:
                    team:
                      description: A Gitea team, as "org:team", whose members are admins on the landing page besides Gitea's site administrators. Empty or absent means site administrators only.
                      type: string
                      maxLength: 200
                      pattern: '^$|^[^:\s]+:[^:\s]+$'
                scale:
                  type: object
                  properties:
                    maxPods:
                      description: The most pods the Scale popup will set on one workload.
                      type: integer
                      minimum: 1
                      maximum: 100
                chat:
                  type: object
                  properties:
                    briefing:
                      description: What the whiteboard's model is told about this place, beyond the list of apps.
                      type: string
                      maxLength: 24000
            status:
              type: object
              properties:
                chat:
                  type: object
                  properties:
                    model:
                      description: The model chosen in the whiteboard's menu. Written by the landing page.
                      type: string
                      maxLength: 300
                locks:
                  description: The page's locks, written by the landing page when an admin locks or unlocks a part. While a part is locked nobody can change it from the page.
                  type: object
                  properties:
                    system:
                      description: The System entries' controls, deleting a node, the API key.
                      type: object
                      properties:
                        locked:
                          type: boolean
                        by:
                          description: Who locked or unlocked last.
                          type: string
                          maxLength: 200
                        at:
                          description: When, in UTC.
                          type: string
                          maxLength: 40
                        sync:
                          description: What the admin sync run at that moment did.
                          type: string
                          maxLength: 500
                    apps:
                      description: The Apps entries' controls.
                      type: object
                      properties:
                        locked:
                          type: boolean
                        by:
                          description: Who locked or unlocked last.
                          type: string
                          maxLength: 200
                        at:
                          description: When, in UTC.
                          type: string
                          maxLength: 40
                        sync:
                          description: What the admin sync run at that moment did.
                          type: string
                          maxLength: 500
                    whiteboard:
                      description: Saying, drawing, erasing, choosing or installing a model.
                      type: object
                      properties:
                        locked:
                          type: boolean
                        by:
                          description: Who locked or unlocked last.
                          type: string
                          maxLength: 200
                        at:
                          description: When, in UTC.
                          type: string
                          maxLength: 40
                        sync:
                          description: What the admin sync run at that moment did.
                          type: string
                          maxLength: 500
                lock:
                  description: (Superseded by locks.system.) The System lock. Written by the landing page when an admin locks or unlocks; while locked, nobody can change a System app, delete a node or change the API key from the page.
                  type: object
                  properties:
                    locked:
                      type: boolean
                    by:
                      description: Who locked or unlocked last.
                      type: string
                      maxLength: 200
                    at:
                      description: When, in UTC.
                      type: string
                      maxLength: 40
                    sync:
                      description: What the admin sync run at that moment did.
                      type: string
                      maxLength: 500
EOF
}

resource "kubectl_manifest" "aviaryconfig" {
  yaml_body = yamlencode({
    apiVersion = "aviary.xdebbie.org/v1alpha1"
    kind       = "AviaryConfig"
    metadata   = { name = "aviary" }
    spec = merge(
      {
        session = { minutes = var.aviary_session_minutes }
        scale   = { maxPods = var.aviary_scale_max_pods }
      },
      var.aviary_admin_team != "" ? { admin = { team = var.aviary_admin_team } } : {},
      var.aviary_chat_briefing != "" ? { chat = { briefing = var.aviary_chat_briefing } } : {},
    )
  })
  depends_on = [kubectl_manifest.aviaryconfig_crd]
}
