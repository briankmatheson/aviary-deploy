# Cert-manager node trust DaemonSet
# Set to false (or TF_VAR_enable_cert_manager_node_trust=false) to skip
# pushing the internal CA into node trust stores on a given run.
enable_cert_manager_node_trust = true

# Kubernetes configuration
kubeconfig = "/home/bmath/k8s/home/1/kubeconfig.yaml"

# Grafanacrt"'' Variables
grafana_namespace       = "grafana"
grafana_admin_password  = "px8QCt6xAkVk"
grafana_host            = "grafana.local"
grafana_tls_secret_name = "grafana-tls"
ingress_class           = "nginx"
cluster_issuer          = "ca-issuer"

# Harbor Variables
harbor_namespace      = "harbor"
harbor_cluster_issuer = "ca-issuer"

harbor_ingress_host  = "harbor.local"
harbor_ingress_class = "nginx"
harbor_external_url  = "https://harbor.local"
harbor_ipv6_enabled  = false

# Gitea Variables
gitea_namespace      = "gitea"
gitea_admin_password = "an7Cu3yhv7Nn"
global_storage_class = "standard"
host_aliases = [
  { ip = "192.168.1.5", hostnames = ["gitea.local"] },
  { ip = "192.168.1.10", hostnames = ["ssh.gitea.local"] }
]
ssh_external_host    = "ssh.gitea.local"
ssh_load_balancer_ip = "192.168.1.10"
ingress_hosts        = ["gitea", "gitea.local", "ssh.gitea.local"]
redis_enabled        = true
postgresql_enabled   = true

# MLflow Variables
mlflow_namespace       = "mlflow"
mlflow_host            = "mlflow.local"
mlflow_tls_secret_name = "mlflow-tls"
mlflow_ingress_class   = "nginx"
mlflow_cluster_issuer  = "ca-issuer"

# MinIO Variables
minio_namespace       = "minio"
minio_host            = "minio.local"
minio_tls_secret_name = "minio-tls"
minio_ingress_class   = "nginx"
minio_cluster_issuer  = "ca-issuer"
minio_user            = "storage-user"
minio_password        = "gazntzMvdV6V"
minio_velero_access   = "backup-user"
minio_velero_secret   = "uBytLY8g8NSq"

# JupyterHub Variables
jupyterhub_namespace       = "jupyterhub"
jupyterhub_host            = "jupyterhub.local"
jupyterhub_tls_secret_name = "jupyterhub-tls"
jupyterhub_ingress_class   = "nginx"
jupyterhub_cluster_issuer  = "ca-issuer"

# Values for Rustpad
rustpad_namespace       = "rustpad"
rustpad_pvc_size        = 4
rustpad_ingress_class   = "nginx"
rustpad_tls_secret_name = "rustpad-tls"
rustpad_ingress_host    = "rustpad.local"

# Values for Prometheus
prometheus_namespace      = "prometheus"
prometheus_admin_password = "admin"

# Values for Percona Postgres
percona_postgres_namespace = "percona-postgres"

# Values for Zalando Postgres
zalando_postgres_namespace          = "zalando-postgres"
zalando_postgres_ui_ingress_class   = "nginx"
zalando_postgres_ui_tls_secret_name = "postgres-ui-tls"
zalando_postgres_ui_ingress_host    = "postgres-ui.local"

# Velero Variables
velero_credentials_secret      = "NMPKXWCg7g2R"
velero_backup_storage_name     = "backups"
velero_backup_storage_provider = "aws"
velero_backup_storage_bucket   = "velero-backups"
velero_backup_storage_region   = "us-east-1"

# Values for System
cilium_ip_address_pool = "192.168.1.8/29"
nfs_server             = "192.168.1.25"
nfs_share              = "/export/nfs"

# Values for Redis
redis_namespace    = "redis"
redis_auth_enabled = false
redis_architecture = "standalone"
