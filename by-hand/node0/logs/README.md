# Logs: a Loki on node0 that outlives the workload clusters

Applied by hand on the management cluster (node0), 2026-11-17. node0 is not
managed by these stacks.

- **Store**: Loki (chart 7.6.0, single binary) in namespace `loki`. Files on
  the node's own disk at `/var/lib/loki` (node0 has no storage class), kept
  for 14 days. There is no size cap, only the retention period: the disk is
  shared with the registry, so watch it.
- **Door**: the chart's nginx gateway asks for a password, and is routed on
  node0's shared gateway under the registry's name --
  `https://registry.mesh.<domain>/loki/...` -- so no second hostname, DNS
  record or certificate is needed (Loki's paths all begin `/loki/`, the
  registry's `/v2/`). User `logs`; the password is in Secret
  `loki/loki-push-credentials` on node0 (its apr1 hash in `loki-gateway-auth`).
- **Collectors**: promtail on node0 (label `cluster=node0`) pushes to the
  Loki beside it. Each workload cluster's promtail pushes there too, as well
  as to its own Loki (`loki_remote_url` in system/loki.tf; on w10 it was set
  with `w10-promtail-values.yaml`, its password in Secret
  `aviary-grafana/loki-node0`).
- **Reading**: Grafana on w10 has the data source "Loki (node0)" (a Secret
  labelled `grafana_datasource=1`, `aviary-grafana/grafana-datasource-loki-node0`,
  carrying the password and the platform CA).

```
export KUBECONFIG=~/.kube/node0-config
kubectl create namespace loki
PW=$(openssl rand -base64 30 | tr -d '/+=' | cut -c1-28)
kubectl -n loki create secret generic loki-gateway-auth --from-literal=.htpasswd="logs:$(openssl passwd -apr1 "$PW")"
kubectl -n loki create secret generic loki-push-credentials --from-literal=username=logs --from-literal=password="$PW"
helm upgrade --install loki loki --repo https://grafana.github.io/helm-charts --version 7.6.0 -n loki -f loki-values.yaml --server-side=false
kubectl apply -f route.yaml
helm upgrade --install promtail promtail --repo https://grafana.github.io/helm-charts --version 6.17.1 -n loki -f promtail-values.yaml --server-side=false
```

Not collected yet, on either cluster: node-level logs (kubelet, containerd,
the journal), Kubernetes events, the API audit log, and the hosts outside
Kubernetes. Promtail itself is past its end of life upstream; Grafana Alloy
is its replacement.
