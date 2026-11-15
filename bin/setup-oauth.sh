#!/usr/bin/env bash
# Register (or re-register) the Gitea OAuth2 application for the aviary landing
# page and write its client id/secret + the session/bypass secrets into
# terraform.tfvars. Idempotent: an existing app named "aviary" is replaced, and
# session/bypass secrets already in tfvars are kept. Gitea must be serving
# (run after the stacks are up). `make oauth` runs this and re-applies apps.
#
# Config is read from terraform.tfvars: base_domain, ns_prefix (default
# "aviary-"), kubeconfig, gitea_admin_password. Override the admin user with
# GITEA_ADMIN (default gitea_admin) and the local forward port with PORT.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
TFVARS=terraform.tfvars
APP_NAME=aviary
PORT=${PORT:-13000}

tfv() { sed -n "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*\"\([^\"]*\)\".*/\1/p" "$TFVARS" | head -1; }

BASE_DOMAIN=$(tfv base_domain)
[ -n "$BASE_DOMAIN" ] || { echo "base_domain not set in $TFVARS" >&2; exit 1; }
NS_PREFIX=$(tfv ns_prefix); NS_PREFIX=${NS_PREFIX:-aviary-}
GITEA_NS="${NS_PREFIX}gitea"
ADMIN=${GITEA_ADMIN:-gitea_admin}
PASS=$(tfv gitea_admin_password)
[ -n "$PASS" ] || { echo "gitea_admin_password not set in $TFVARS" >&2; exit 1; }
KC=$(tfv kubeconfig)
export KUBECONFIG="${KUBECONFIG:-$KC}"
REDIR="https://aviary.${BASE_DOMAIN}/oauth/callback"

echo "Registering Gitea OAuth2 app '$APP_NAME' (redirect $REDIR) via $GITEA_NS/gitea-http ..."
kubectl -n "$GITEA_NS" port-forward svc/gitea-http "$PORT:3000" >/dev/null 2>&1 &
PF=$!
trap 'kill $PF 2>/dev/null || true' EXIT
G="http://127.0.0.1:$PORT"
for i in $(seq 1 30); do
  curl -sf -o /dev/null "$G/api/v1/version" && break
  [ "$i" = 30 ] && { echo "gitea not reachable via port-forward" >&2; exit 1; }
  sleep 1
done

# Replace any existing app of this name so re-runs stay to a single client.
for id in $(curl -s -u "$ADMIN:$PASS" "$G/api/v1/user/applications/oauth2" \
            | jq -r ".[] | select(.name==\"$APP_NAME\") | .id"); do
  echo "  removing existing app id=$id"
  curl -s -o /dev/null -X DELETE -u "$ADMIN:$PASS" "$G/api/v1/user/applications/oauth2/$id"
done

resp=$(curl -s -u "$ADMIN:$PASS" -X POST "$G/api/v1/user/applications/oauth2" \
  -H 'Content-Type: application/json' \
  -d "{\"name\":\"$APP_NAME\",\"redirect_uris\":[\"$REDIR\"],\"confidential_client\":true}")
CID=$(echo "$resp" | jq -r '.client_id // empty')
CSEC=$(echo "$resp" | jq -r '.client_secret // empty')
[ -n "$CID" ] && [ -n "$CSEC" ] || { echo "app creation failed: $resp" >&2; exit 1; }

# Reuse session/bypass secrets if already set, else mint fresh ones.
SESS=$(tfv aviary_session_secret); [ -n "$SESS" ] || SESS=$(openssl rand -hex 32)
BYP=$(tfv aviary_bypass_token);    [ -n "$BYP" ]  || BYP=$(openssl rand -hex 24)

setvar() {
  local k=$1 v
  v=$(printf '%s' "$2" | sed 's/[&|\\]/\\&/g')
  if grep -qE "^[[:space:]]*$k[[:space:]]*=" "$TFVARS"; then
    sed -i -E "s|^([[:space:]]*$k[[:space:]]*=).*|\1 \"$v\"|" "$TFVARS"
  else
    printf '%s = "%s"\n' "$k" "$2" >> "$TFVARS"
  fi
}
setvar aviary_oauth_client_id "$CID"
setvar aviary_oauth_client_secret "$CSEC"
setvar aviary_session_secret "$SESS"
setvar aviary_bypass_token "$BYP"

echo "OK: aviary OAuth2 app registered (client_id=$CID), wrote aviary_oauth_* into $TFVARS"
echo "    bypass token: $BYP"
