# coredns-ui for the authoritative DNS

A console (metrics, logs, the Corefile, restart, scale) for the CoreDNS in
`aviary-dns`, at `coredns-ui.<base_domain>`, System group, behind the
admins-only Gitea gate. Applied by hand; nothing in the stacks creates it.

- Upstream: https://github.com/beztebya666/coredns-ui (v1.0.0, MIT). A small,
  young project with no login of its own, hence the fences below.
- `aviary.patch`: upstream fixes the CoreDNS it manages to kube-system's. The
  patch reads it from `DNS_NAMESPACE`, `DNS_DEPLOYMENT`, `DNS_CONFIGMAP`,
  `DNS_SELECTOR`, `DNS_SERVICE`, and makes the build verify Go module
  checksums (upstream turns that off and uses a third-party module proxy).
  Build and push:

  ```
  git clone https://github.com/beztebya666/coredns-ui && cd coredns-ui
  git apply /path/to/aviary.patch
  docker build --network=host -t registry.<mesh domain>/coredns-ui:1.0.0-aviary1 app/
  docker push registry.<mesh domain>/coredns-ui:1.0.0-aviary1
  ```

- `coredns-ui.yaml`: the ServiceAccount, a Role for this namespace only (no
  cluster-wide access: its cluster inventory pages stay empty), the
  Deployment, the Service, and a CiliumNetworkPolicy (in: the gateway's
  proxies; out: the cluster, nothing on the internet). It needs the `mesh-reg`
  pull secret in `aviary-dns`.
- The gate, route, listener and certificate are as for the other System apps
  (see ../README.md).

The Corefile and zone files in ConfigMap `dns` are written by
`system/dns.tf`: an edit made in the console lasts until the next apply.
