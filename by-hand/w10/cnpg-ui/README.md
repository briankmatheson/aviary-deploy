# cnpg-ui for the CloudNativePG databases

https://github.com/dbonne/cnpg-ui (0.1.0, Apache-2.0), at
`cnpg-ui.<base_domain>`, System group, behind the admins-only Gitea gate.
Applied by hand; nothing in the stacks creates it.

- It manages one namespace (`CNPG_UI_NAMESPACE`): `aviary-mattermost`, the
  only one with a CloudNativePG cluster. Another namespace's databases need
  a second instance, or upstream support for more than one.
- `cnpg-ui.yaml` instead of the upstream chart, whose ClusterRole reaches
  every namespace and can read every Secret: here a Role in the managed
  namespace only, and its own credentials Secret by name. The image is pinned
  by digest. CiliumNetworkPolicy: in from the gateway's proxies, out to the
  cluster only.
- Its own login stays on behind the gate: user `admin`. The bcrypt hash is in
  `aviary-mattermost/cnpg-ui-credentials` (keys `username`, `password_hash`),
  the password in `aviary-cnpg-ui/cnpg-ui-admin`; both are made by hand:

  ```
  PW=$(openssl rand -base64 30 | tr -d '/+=' | cut -c1-24)
  HASH=$(PW="$PW" python3 -c 'import bcrypt,os; print(bcrypt.hashpw(os.environ["PW"].encode(), bcrypt.gensalt(12)).decode())')
  kubectl -n aviary-mattermost create secret generic cnpg-ui-credentials --from-literal=username=admin --from-literal=password_hash="$HASH"
  kubectl -n aviary-cnpg-ui create secret generic cnpg-ui-admin --from-literal=username=admin --from-literal=password="$PW"
  ```

- Its pages are under `/ui/`: the route redirects `/` to `/ui/clusters`
  (a redirect with no backend, so the landing page's row is unaffected).
