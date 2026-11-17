# Admins follow Gitea's "Is Administrator" flag

**Not applied yet (written 2026-11-17).** The steps below create a Gitea
access token and a job that changes team membership, so they are left for a
person to run.

An Aviary admin is a Gitea site administrator: the `is_admin` flag on the
account. The landing page reads that flag directly at sign-in.

The gateway's gates in front of the System apps cannot. Gitea's ID token
carries no administrator claim, only `groups` (teams), so the gates check for
`aviary:admins`. This job closes the gap: every two minutes it makes the
team's members exactly the active site administrators. Ticking or unticking
**Is Administrator** on an account is then the only thing anyone does; the
team is never edited by hand (a hand edit is undone at the next run).

- It refuses to act if Gitea lists no site administrators, so a failed or
  empty answer cannot empty the team.
- A change reaches a gate when the person next signs in to it (the gates do
  not refresh tokens); `https://<app>.<domain>/oauth2/logout` forces that.
- The token belongs to `gitea_admin`, scoped `read:admin` and
  `write:organization`. It can list users and edit organisations and teams;
  it cannot read repositories or change accounts.

## Apply

```
export KUBECONFIG=~/.kube/w10-config
G=https://gitea.<domain>

# 1. A token for gitea_admin (password: the gitea chart's admin password).
TOKEN=$(curl -s -u gitea_admin -H 'Content-Type: application/json' \
  -X POST $G/api/v1/users/gitea_admin/tokens \
  -d '{"name":"aviary-admin-sync","scopes":["read:admin","write:organization"]}' | jq -r .sha1)
kubectl -n aviary-gitea create secret generic aviary-admin-sync --from-literal=token="$TOKEN"

# 2. The script and the schedule.
kubectl -n aviary-gitea create configmap aviary-admin-sync --from-file=sync.py
kubectl apply -f cronjob.yaml

# 3. Run it once and read what it did.
kubectl -n aviary-gitea create job admin-sync-first --from=cronjob/aviary-admin-sync
kubectl -n aviary-gitea logs -f job/admin-sync-first
```

To see what it would do without changing anything, run the script with
`DRY_RUN=1` (and `GITEA_URL`, `TOKEN_FILE`) set.

On 2026-11-17 the two sets were already equal (`bmath`, `gitea_admin`), so
the first run should report no change.

## Remove

```
kubectl -n aviary-gitea delete cronjob/aviary-admin-sync configmap/aviary-admin-sync secret/aviary-admin-sync
```

and delete the token `aviary-admin-sync` under gitea_admin's Settings >
Applications.
