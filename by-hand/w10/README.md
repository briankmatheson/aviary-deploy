# Applied by hand on w10

What is on the w10 cluster that the OpenTofu stacks do not create. The YAML
here is exported from the cluster (2026-11-16), so it is a record to rebuild
from, not something `make apply` reads. No secrets are in it: client secrets
live in the Kubernetes Secrets named below and have to be re-issued in Gitea
on a rebuild.

## Who is an admin

Gitea organisation `aviary` (private), team `admins`. Members get
`aviary:admins` in the `groups` claim of Gitea's ID token. The System gates
and the landing page (`ADMIN_TEAM`) both go by it.

## Gitea OAuth2 applications (owned by `gitea_admin`)

| App | Used by | Redirect URIs | Secret kept in |
|---|---|---|---|
| `aviary` | landing page | `/oauth/callback` | `aviary/aviary-frontend-oauth` |
| `drone` | Drone | `/login` | Drone's helm values |
| `aviary-gateway` | gates: jitsi, rustpad, cloudbeaver | `https://<app>.<domain>/oauth2/callback` | `aviary-gateway-oidc` in each app's namespace |
| `aviary-gateway-system` | gates: kubeshark, headlamp, velero, grafana, bash | same shape | `aviary-gateway-system-oidc` in each namespace |
| `axigen` | Axigen WebMail | `https://mail.<domain>:443/?action=oauthLogin&custom=ajaxdirect` | Axigen's config; copy in `aviary-axigen/gitea-oidc-client` |
| `harbor` | Harbor | `/c/oidc/callback` | Harbor's config; copy in `aviary-harbor/gitea-oidc-client` |

Editing an application through Gitea's API (PATCH) issues a new client
secret: take it from the response and update every Secret that holds it.

## Gates (`gates-*.yaml`, `httproutes.yaml`, `gateway-listeners.yaml`)

Envoy Gateway `SecurityPolicy` per route, each with a `ReferenceGrant` in
`aviary-gitea` so it may reach `gitea-http`.

- Apps (jitsi, rustpad): Gitea login, any user.
- System (kubeshark, headlamp, velero, grafana, bash): Gitea login, then the ID
  token (forwarded as `X-Aviary-Id-Token`, checked against Gitea's keys over
  in-cluster HTTP) must carry `aviary:admins`; everything else is denied. No
  token refresh. The routes strip the header before the app sees it.
- CloudBeaver: Gitea login, and the token's `preferred_username` is handed to
  CloudBeaver as `X-User`; the route pins `X-Team` to `user`.
- kubeshark and cloudbeaver also needed a listener on Gateway `aviary` (their
  certificates follow from that) and their own `HTTPRoute`.
- The gitea route redirects Gitea's favicon paths to the landing page's icon.
  Keep it a redirect: a second backend on that route makes the landing page
  draw the gitea row from the wrong namespace.

## Axigen WebMail signs in with Gitea (`axigen-gitea-login.yaml`)

- `gitea-oidc-discovery`: a copy of Gitea's discovery document whose token,
  keys and userinfo endpoints point at `gitea-http` in-cluster (Axigen does
  not trust the private CA) and which leaves out
  `code_challenge_methods_supported` (Axigen then sends a PKCE verifier with
  no challenge, which Gitea refuses).
- `axigen-mail-wm-direct`: WebMail straight from the backend's plain-HTTP
  listener on port 443; the `mail` route points at it instead of the
  front-end proxy. Axigen builds its redirect URI from the listener's port.
- In Axigen's CLI on the backend (port 7000, admin):

  ```
  config server
  config webmail
  add listener address 0.0.0.0:443
  commit
  commit
  config server
  config userdb
  add oauthconnector name gitea mode oidc
  set clientId <client id>
  set clientSecret <client secret>
  set autoConfigUri http://gitea-oidc-discovery.aviary-axigen.svc.cluster.local/.well-known/openid-configuration?v=2
  set clientScopes "openid profile email"
  set usernameField preferred_username
  commit
  commit
  config server
  config webmail
  set userdbConnectorType oauth
  set userdbConnectorName gitea
  commit
  save config
  ```

- A Gitea user `name` opens the mailbox `name@<mail domain>`, which has to
  exist already.

## Harbor signs in with Gitea

`PUT /api/v2.0/configurations` as Harbor's admin: `auth_mode: oidc_auth`,
`oidc_name: Gitea`, `oidc_endpoint: https://gitea.<domain>`, the `harbor`
application's id and secret, `oidc_scope: openid,profile,email`,
`oidc_verify_cert: false`, `oidc_auto_onboard: true`,
`oidc_user_claim: preferred_username`, `primary_auth_mode: true`.

## CloudBeaver

- Reverse-proxy sign-in is switched on in its runtime configuration on the
  volume (`/opt/cloudbeaver/workspace/.data/.cloudbeaver.runtime.conf`):
  `"enableReverseProxyAuth": true` and `"reverseProxy"` added to
  `enabledAuthProviders`, then a restart.
- `cloudbeaver-networkpolicy.yaml` is the same policy `apps/cloudbeaver.tf`
  creates.

## Chat model's briefing

The `briefing` key of ConfigMap `aviary/aviary-chat`.
