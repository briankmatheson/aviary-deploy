# Gitea's sign-in pages in Aviary's look

Gitea is the identity provider, so its sign-in page is the door to
everything. `templates/custom/` here are two of Gitea's customization hooks
(1.27): on the sign-in, two-factor, forgot-password and "Authorize
application" pages they hide Gitea's navigation and footer, put Aviary's
grid behind the box and Aviary's name over it. CSS only; every other Gitea
page is untouched.

They live on Gitea's volume, in its custom directory (`$GITEA_CUSTOM`,
`/data/gitea`), and are read at start:

```
kubectl -n aviary-gitea exec -i deploy/gitea -c gitea -- sh -c \
  'mkdir -p /data/gitea/templates/custom && cat > /data/gitea/templates/custom/header.tmpl' < templates/custom/header.tmpl
kubectl -n aviary-gitea exec -i deploy/gitea -c gitea -- sh -c \
  'cat > /data/gitea/templates/custom/body_outer_pre.tmpl' < templates/custom/body_outer_pre.tmpl
kubectl -n aviary-gitea rollout restart deploy/gitea   # about two minutes without logins
```

`body_outer_pre.tmpl` carries the landing page's address: change it with
`base_domain`. The browser tab still says "Sign In - Gitea: ..." (Gitea's
`APP_NAME`).
