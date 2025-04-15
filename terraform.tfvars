# Kubernetes configuration
kubeconfig = "/home/bmath/k8s/q11/kubeconfig.yaml"

# Grafana Variables
grafana_namespace       = "grafana"
grafana_admin_password  = "securepassword"
grafana_host            = "grafana.local"
grafana_tls_secret_name = "grafana-tls"
ingress_class           = "nginx"
cluster_issuer          = "letsencrypt-prod"

# Harbor Variables
harbor_namespace       = "harbor"
harbor_expose_type     = "ingress"
harbor_ingress_host    = "harbor.local"
harbor_ingress_class   = "nginx"
harbor_external_url    = "https://harbor.local"
harbor_ipv6_enabled    = false

# Gitea Variables
gitea_namespace       =  "gitea"
gitea_admin_password    = "rrrrrrrr"
global_storage_class    = "standard"
host_aliases            = [
  { ip = "192.168.122.7", hostnames = ["gitea"] },
  { ip = "192.168.122.9", hostnames = ["ssh.gitea.local"] }
]
ssh_external_host       = "ssh.gitea.local"
ssh_load_balancer_ip    = "192.168.122.9"
ingress_hosts           = ["gitea", "gitea.local", "ssh.gitea.local"]
redis_enabled           = true
postgresql_enabled      = true

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
minio_root_user       = "minio"
minio_root_password   = "minio123"

# JupyterHub Variables
jupyterhub_namespace       = "jupyterhub"
jupyterhub_host            = "jupyterhub.local"
jupyterhub_tls_secret_name = "jupyterhub-tls"
jupyterhub_ingress_class   = "nginx"
jupyterhub_cluster_issuer  = "ca-issuer"

# Values for Rustpad
rustpad_namespace = "rustpad"
rustpad_ingress_class = "nginx"
rustpad_tls_secret_name = "rustpad-tls"
rustpad_ingress_host = "rustpad.local"

# Values for Prometheus
prometheus_namespace = "prometheus"
prometheus_admin_password = "admin"

# Values for Percona Postgres
percona_postgres_namespace = "percona-postgres"

# Values for Zalando Postgres
zalando_postgres_namespace = "zalando-postgres"
zalando_postgres_ui_ingress_class = "nginx"
zalando_postgres_ui_tls_secret_name = "postgres-ui-tls"
zalando_postgres_ui_ingress_host = "postgres-ui.local"

# Velero Variables
velero_credentials_secret = ""
velero_backup_storage_name = ""
velero_backup_storage_provider = ""
velero_backup_storage_bucket = ""
velero_backup_storage_region = ""
velero_snapshot_location_name = ""
velero_snapshot_location_provider = ""
velero_snapshot_location_region = ""
velero_init_container_name = ""
velero_init_container_image = ""
velero_init_container_mount_path = ""
velero_init_container_volume_name = ""

# Values for System
metallb_ip_address_pool = [
  "192.168.122.6/32",
  "192.168.122.7/32",
  "192.168.122.8/32",
  "192.168.122.9/32"
]
nfs_server = "192.168.122.5"
nfs_share = "/export"
ingress_nginx_external_ip = "192.168.122.6"
dashboard_ingress_host = "kubernetes-dashboard.local"
dashboard_tls_secret_name = "kubernetes-dashboard-tls"

# Values for Redis
redis_namespace = "redis"
redis_auth_enabled = false
redis_architecture = "standalone"