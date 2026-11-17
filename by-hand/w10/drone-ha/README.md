# Drone: from one server on SQLite to three on Postgres

Done by hand on w10, 2026-11-17. apps/drone.tf describes the result
(`drone_db_password` set); this is how the existing data got there.

Drone's HA mode is **beta upstream** (docs.drone.io/server/ha/overview):
every server points at the same Postgres and the same Redis-compatible
store, and shares one cookie secret. Runners reach the servers through the
`drone` Service, which spreads them.

What was done, in order:

1. Kept the old volume whatever happens next: the PersistentVolume's reclaim
   policy set to `Retain`, and the claim `drone` annotated
   `helm.sh/resource-policy: keep` (the chart drops the claim once
   `persistentVolume.enabled` is false).
2. `infra.yaml`: a cnpg Cluster `drone-pg` and a Valkey Deployment. Secret
   `drone-ha` holds the Valkey password, `DRONE_COOKIE_SECRET`, and the
   `DRONE_DATABASE_*` / `DRONE_REDIS_CONNECTION` settings.
3. With no build running, scaled the server to 0 and copied
   `/data/database.sqlite` out through a pod mounting the claim read-only
   (md5 matched, `pragma integrity_check` ok).
4. Started Drone once against the empty Postgres (a throwaway pod with the
   same environment) so that it created its own tables, then stopped it.
5. `import.py <database.sqlite>` with `PG_DSN` set (through
   `kubectl port-forward svc/drone-pg-rw`): empties the tables, copies every
   table but `migrations` in one transaction, converts booleans and blobs to
   the target column types, moves the sequences past the copied ids, and
   refuses to commit unless the row counts match. Copied: 198 builds, 198
   stages, 265 steps, 263 logs, 7 repos, 7 perms, 3 users, 1 secret.
6. `helm upgrade drone apps/charts/drone --reuse-values -f ha-values.yaml`.

Going back: `helm upgrade` with `persistentVolume.enabled=true`,
`replicaCount=1`, `updateStrategy.type=Recreate` and no
`extraSecretNamesForEnvFrom`; the SQLite file on the kept claim is as it was
at step 3 (anything built since is only in Postgres).

Still single: Postgres (one instance) and Valkey (one pod, nothing kept on
disk). Three servers survive the loss of a server's node; they do not
survive the loss of either of those.
