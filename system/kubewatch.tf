# kubewatch watches the cluster and posts resource changes to Mattermost via the
# native mattermost handler, pointed at a Mattermost incoming webhook (created
# after Mattermost's first-run). Not web-facing -- it only talks outward -- so no
# gateway vhost. The chart creates the cluster-wide read/watch RBAC it needs.

resource "helm_release" "kubewatch" {
  name             = "kubewatch"
  repository       = "https://robusta-charts.storage.googleapis.com"
  chart            = "kubewatch"
  namespace        = "${var.ns_prefix}kubewatch"
  create_namespace = true

  values = [yamlencode({
    rbac = { create = true }

    # Mattermost incoming webhooks are Slack-compatible; this handler posts
    # formatted events to the webhook's channel.
    mattermost = {
      enabled  = true
      url      = var.kubewatch_mattermost_webhook
      channel  = var.kubewatch_mattermost_channel
      username = "kubewatch"
    }

    # A useful, non-spammy default (pod/replicaset/event left off -- too chatty
    # during rollouts; flip them on for the firehose).
    resourcesToWatch = {
      deployment            = true
      daemonset             = true
      services              = true
      job                   = true
      persistentvolume      = true
      pod                   = false
      replicaset            = false
      replicationcontroller = false
      event                 = false
    }
  })]
}
