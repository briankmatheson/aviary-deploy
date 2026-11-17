#!/bin/bash
# Install the admin sync on w10: a Gitea token for gitea_admin, the script,
# the schedule, and one run to show what it does. Safe to run again (it
# keeps an existing token). See README.md.
set -euo pipefail
cd "$(dirname "$0")"
export KUBECONFIG=${KUBECONFIG:-$HOME/.kube/w10-config}
NS=aviary-gitea
G=https://$(kubectl get httproute -A -o json | jq -r '[.items[]|select(.metadata.name=="gitea")|.spec.hostnames[0]][0]')

if ! kubectl -n $NS get secret aviary-admin-sync >/dev/null 2>&1; then
  # gitea_admin's password, as the gitea chart was given it
  P=$(kubectl -n $NS get deploy gitea -o json | jq -r '.spec.template.spec.initContainers[]|select(.name=="configure-gitea").env[]|select(.name=="GITEA_ADMIN_PASSWORD").value')
  TOKEN=$(curl -fsS -u "gitea_admin:$P" -H 'Content-Type: application/json' -X POST "$G/api/v1/users/gitea_admin/tokens" \
    -d '{"name":"aviary-admin-sync","scopes":["read:admin","write:organization"]}' | jq -r .sha1)
  [ -n "$TOKEN" ] && [ "$TOKEN" != null ] || { echo "could not create the token" >&2; exit 1; }
  kubectl -n $NS create secret generic aviary-admin-sync --from-literal=token="$TOKEN"
fi
kubectl -n $NS create configmap aviary-admin-sync --from-file=sync.py --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f cronjob.yaml

kubectl -n $NS delete job admin-sync-first --ignore-not-found >/dev/null
kubectl -n $NS create job admin-sync-first --from=cronjob/aviary-admin-sync
kubectl -n $NS wait --for=condition=complete job/admin-sync-first --timeout=180s || true
echo "--- what the first run did:"
kubectl -n $NS logs job/admin-sync-first
