#!/usr/bin/env bash
# Register the aviary zone in the management cluster's CoreDNS (reachable at
# 10.23.0.11), a faithful port of simple/bin/mesh-zone.sh: a wildcard template
# sends every <app>.<base_domain> at the shared Gateway's LoadBalancer IP, with
# ssh.gitea.<base_domain> sent to the Gitea ssh LoadBalancer instead.
#
# Run it after `make apply` — the Gateway must already have its LB address.
#
#   KUBECONFIG of the workload cluster: terraform.tfvars `kubeconfig`
#   KUBECONFIG of the DNS (management) cluster: DNS_KUBECONFIG (default
#     ~/.kube/node0-config), the CoreDNS behind 10.23.0.11
#
# Note: boxes that resolve through the host CoreDNS (10.23.0.1) also need the
# sub-zone delegated there (simple: `make dns DNS_SUBZONES="aviary=10.23.0.11"`).
# Clients already pointed at 10.23.0.11 (e.g. xdj-joined laptops) need nothing.
set -euo pipefail

TFVARS=${TFVARS:-terraform.tfvars}
val() { sed -n "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*\"\{0,1\}\([^\"#]*\)\"\{0,1\}.*/\1/p" "$TFVARS" 2>/dev/null | head -1 | sed 's/[[:space:]]*$//'; }

BASE_DOMAIN=${BASE_DOMAIN:-$(val base_domain)}
SSH_IP=${SSH_LOAD_BALANCER_IP:-$(val ssh_load_balancer_ip)}
GW_NAME=${GATEWAY_NAME:-aviary}
GW_NS=${GATEWAY_NAMESPACE:-envoy-gateway}
WORKLOAD_KUBECONFIG=${WORKLOAD_KUBECONFIG:-$(val kubeconfig)}
DNS_KUBECONFIG=${DNS_KUBECONFIG:-$HOME/.kube/node0-config}

[ -n "$BASE_DOMAIN" ] || { echo "set-dns: base_domain not found in $TFVARS" >&2; exit 1; }
[ -s "$DNS_KUBECONFIG" ] || { echo "set-dns: DNS kubeconfig $DNS_KUBECONFIG missing (set DNS_KUBECONFIG)" >&2; exit 1; }

# The Gateway's assigned LoadBalancer IP, from the workload cluster.
GW_IP=$(KUBECONFIG=$WORKLOAD_KUBECONFIG kubectl get gateway "$GW_NAME" -n "$GW_NS" \
    -o jsonpath='{.status.addresses[0].value}' 2>/dev/null || true)
[ -n "$GW_IP" ] || { echo "set-dns: Gateway $GW_NS/$GW_NAME has no LB address yet — is the system stack applied?" >&2; exit 1; }

echo "set-dns: $BASE_DOMAIN -> $GW_IP${SSH_IP:+  (ssh.gitea.$BASE_DOMAIN -> $SSH_IP)}"

esc() { printf '%s' "$1" | sed 's/\./[.]/g'; }
block="
$BASE_DOMAIN:53 {
    acl {
        allow net 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 127.0.0.0/8
        block
    }
    errors
"
if [ -n "$SSH_IP" ]; then
block+="    template IN A {
        match \"^$(esc "ssh.gitea.$BASE_DOMAIN")[.]\$\"
        answer \"{{ .Name }} 60 IN A $SSH_IP\"
        fallthrough
    }
"
fi
block+="    template IN A {
        answer \"{{ .Name }} 60 IN A $GW_IP\"
    }
    template IN AAAA {
        rcode NOERROR
    }
    cache 30
}
"

k() { KUBECONFIG=$DNS_KUBECONFIG kubectl "$@"; }

# Read-modify-write the shared Corefile: drop any existing block for this zone
# (header line to the first lone closing brace), then append the fresh one.
cur=$(k -n kube-system get cm coredns -o jsonpath='{.data.Corefile}')
new=$(printf '%s\n' "$cur" | awk -v z="$BASE_DOMAIN:53 {" '
    $0 == z { skip = 1; next }
    skip && $0 == "}" { skip = 0; next }
    !skip { print }')
new="$new$block"

printf '%s\n' "$new" | k -n kube-system create cm coredns --from-file=Corefile=/dev/stdin \
    --dry-run=client -o yaml | k apply -f - >/dev/null
k -n kube-system rollout restart deploy/coredns >/dev/null
k -n kube-system rollout status deploy/coredns --timeout=120s >/dev/null
echo "set-dns: ✓ $BASE_DOMAIN in management CoreDNS (10.23.0.11)"

# Best-effort confirmation.
if command -v dig >/dev/null; then
    for i in 1 2 3 4 5; do
        got=$(dig +short +time=2 @10.23.0.11 "probe.$BASE_DOMAIN" 2>/dev/null | tail -1)
        [ "$got" = "$GW_IP" ] && { echo "set-dns: ✓ probe.$BASE_DOMAIN -> $got via 10.23.0.11"; exit 0; }
        sleep 1
    done
    echo "set-dns: ⚠ probe.$BASE_DOMAIN did not resolve to $GW_IP via 10.23.0.11 (got '${got:-}')" >&2
fi
