# =============================================================================
# Consolidated Variables
# =============================================================================

# --- Global ---

variable "kubeconfig" {
  type        = string
  description = "Path to the Kubernetes configuration file."
}

variable "ingress_class" {
  description = "Ingress class for Kubernetes"
  type        = string
  default     = "nginx"
}

variable "cluster_issuer" {
  description = "Cluster issuer for cert-manager"
  type        = string
}

# --- System ---

# Cilium Variables
variable "cilium_ip_address_pool" {
  description = "A CIDR prefix for IP address pool."
  type        = string
}

# NFS Storage Variables
variable "nfs_server" {
  description = "The NFS server address."
  type        = string
}

variable "nfs_share" {
  description = "The NFS share path."
  type        = string
}

# --- Cert-Manager ---

variable "enable_cert_manager_node_trust" {
  description = "Deploy the DaemonSet that installs the internal CA into each node's trust store."
  type        = bool
  default     = true
}

# --- Gitea ---

variable "gitea_namespace" {
  description = "Namespace for Gitea"
  type        = string
  default     = "gitea"
}

variable "gitea_admin_password" {
  description = "Admin password for Gitea"
  type        = string
}

variable "global_storage_class" {
  description = "Global storage class for Gitea"
  type        = string
  default     = "standard"
}

variable "host_aliases" {
  description = "Hostname aliases for Gitea"
  type = list(object({
    ip        = string
    hostnames = list(string)
  }))
}

variable "ssh_external_host" {
  description = "External SSH hostname for Gitea"
  type        = string
}

variable "ssh_load_balancer_ip" {
  description = "LoadBalancer IP for Gitea SSH service"
  type        = string
}

variable "ingress_hosts" {
  description = "Ingress hostnames for Gitea"
  type        = list(string)
}

variable "redis_enabled" {
  description = "Enable Redis for Gitea"
  type        = bool
  default     = true
}

variable "postgresql_enabled" {
  description = "Enable PostgreSQL for Gitea"
  type        = bool
  default     = true
}

# --- Grafana ---

variable "grafana_namespace" {
  description = "Namespace for Grafana"
  type        = string
}

variable "grafana_admin_password" {
  description = "Admin password for Grafana"
  type        = string
}

variable "grafana_host" {
  description = "Host for Grafana ingress"
  type        = string
}

variable "grafana_tls_secret_name" {
  description = "TLS secret name for Grafana ingress"
  type        = string
}

# --- Harbor ---

variable "harbor_namespace" {
  description = "Namespace for Harbor"
  type        = string
}

variable "harbor_ingress_host" {
  description = "Ingress host for Harbor"
  type        = string
}

variable "harbor_ingress_class" {
  description = "Ingress class for Harbor"
  type        = string
}

variable "harbor_cluster_issuer" {
  description = "Cluster issuer for Harbor"
  type        = string
}

variable "harbor_external_url" {
  description = "External URL for Harbor"
  type        = string
}

variable "harbor_ipv6_enabled" {
  description = "Enable IPv6 for Harbor"
  type        = bool
}

# --- JupyterHub ---

variable "jupyterhub_namespace" {
  description = "Namespace for JupyterHub"
  type        = string
}

variable "jupyterhub_host" {
  description = "Host for JupyterHub ingress"
  type        = string
}

variable "jupyterhub_tls_secret_name" {
  description = "TLS secret name for JupyterHub ingress"
  type        = string
}

variable "jupyterhub_ingress_class" {
  description = "Ingress class for JupyterHub"
  type        = string
}

variable "jupyterhub_cluster_issuer" {
  description = "Cluster issuer for JupyterHub"
  type        = string
}

# --- MinIO ---

variable "minio_namespace" {
  description = "Namespace for MinIO"
  type        = string
}

variable "minio_user" {
  description = "Admin user for MinIO."
  type        = string
}

variable "minio_password" {
  description = "Admin password for MinIO."
  type        = string
}

variable "minio_host" {
  description = "Host for MinIO ingress"
  type        = string
}

variable "minio_tls_secret_name" {
  description = "TLS secret name for MinIO ingress"
  type        = string
}

variable "minio_ingress_class" {
  description = "Ingress class for MinIO"
  type        = string
}

variable "minio_cluster_issuer" {
  description = "Cluster issuer for MinIO"
  type        = string
}

variable "minio_velero_access" {
  description = "Velero access username for MinIO"
  type        = string
}

variable "minio_velero_secret" {
  description = "Velero access password for MinIO"
  type        = string
}

# --- MLflow ---

variable "mlflow_namespace" {
  description = "Namespace for MLflow"
  type        = string
}

variable "mlflow_host" {
  description = "Host for MLflow ingress"
  type        = string
}

variable "mlflow_tls_secret_name" {
  description = "TLS secret name for MLflow ingress"
  type        = string
}

variable "mlflow_ingress_class" {
  description = "Ingress class for MLflow"
  type        = string
}

variable "mlflow_cluster_issuer" {
  description = "Cluster issuer for MLflow"
  type        = string
}

# --- Postgres ---

variable "percona_postgres_namespace" {
  description = "The Kubernetes namespace where Percona Postgres will be deployed."
  type        = string
}

variable "zalando_postgres_namespace" {
  description = "The Kubernetes namespace where Zalando Postgres will be deployed."
  type        = string
}

variable "zalando_postgres_ui_ingress_class" {
  description = "The ingress class to be used for Zalando Postgres UI."
  type        = string
}

variable "zalando_postgres_ui_tls_secret_name" {
  description = "The name of the TLS secret for Zalando Postgres UI ingress."
  type        = string
}

variable "zalando_postgres_ui_ingress_host" {
  description = "The hostname for Zalando Postgres UI ingress."
  type        = string
}

# --- Prometheus ---

variable "prometheus_namespace" {
  description = "The Kubernetes namespace where Prometheus will be deployed."
  type        = string
}

variable "prometheus_admin_password" {
  description = "The admin password for Prometheus."
  type        = string
}

# --- Redis ---

variable "redis_namespace" {
  description = "The Kubernetes namespace where Redis will be deployed."
  type        = string
}

variable "redis_auth_enabled" {
  description = "Specifies whether Redis authentication is enabled."
  type        = bool
}

variable "redis_architecture" {
  description = "The architecture of the Redis deployment (standalone|replication)."
  type        = string
}

# --- Rustpad ---

variable "rustpad_namespace" {
  description = "The Kubernetes namespace where Rustpad will be deployed."
  type        = string
}

variable "rustpad_ingress_class" {
  description = "The ingress class to be used for Rustpad."
  type        = string
}

variable "rustpad_tls_secret_name" {
  description = "The name of the TLS secret for Rustpad ingress."
  type        = string
}

variable "rustpad_ingress_host" {
  description = "The hostname for Rustpad ingress."
  type        = string
}

variable "rustpad_pvc_size" {
  description = "The storage size for Rustpad."
  type        = number
}

# --- Velero ---

variable "velero_credentials_secret" {
  description = "The secret contents for Velero credentials."
  type        = string
}

variable "velero_backup_storage_name" {
  description = "The name of the backup storage location for Velero."
  type        = string
}

variable "velero_backup_storage_provider" {
  description = "The provider for the backup storage location for Velero."
  type        = string
}

variable "velero_backup_storage_bucket" {
  description = "The bucket name for the backup storage location for Velero."
  type        = string
}

variable "velero_backup_storage_region" {
  description = "The region for the backup storage location for Velero."
  type        = string
}
