# Shared variables: this file is symlinked into apps/, system/ and data/, and
# every stack reads the same terraform.tfvars (copy terraform.tfvars.example).
# Modules in disabled/ carry their own variable blocks.

# --- Global ---

variable "kubeconfig" {
  type        = string
  description = "Path to the kubeconfig for the target cluster."
}

variable "cluster_issuer" {
  description = "cert-manager ClusterIssuer that signs the Gateway's TLS certificates."
  type        = string
  default     = "ca-issuer"
}

variable "base_domain" {
  description = <<-EOT
    DNS domain the apps hang off: each app is served at <app>.<base_domain>
    and the landing page at <base_domain> itself. Point a wildcard (or
    /etc/hosts entries) at the Gateway's LoadBalancer IP.
  EOT
  type        = string
  default     = "aviary.<base_domain>"
}

variable "global_storage_class" {
  description = "StorageClass for persistent volumes (gitea, grafana, rustpad)."
  type        = string
  default     = "standard"
}

# --- Aviary frontend ---

variable "aviary_frontend_image" {
  description = "Landing page image (github.com/briankmatheson/aviary-frontend; `make push REGISTRY=...` to use your own registry)."
  type        = string
  default     = "briankmatheson/aviary-frontend:1.0.1"
}

# --- Gitea ---

variable "gitea_admin_password" {
  description = "Admin password for Gitea."
  type        = string
  sensitive   = true
}

variable "ssh_external_host" {
  description = "Hostname Gitea advertises for ssh clone URLs. Empty: ssh.gitea.<base_domain>."
  type        = string
  default     = ""
}

variable "ssh_load_balancer_ip" {
  description = "LoadBalancer IP for the Gitea ssh Service (from your LB pool)."
  type        = string
}

variable "postgresql_enabled" {
  description = "Use the chart's bundled single-node PostgreSQL for Gitea."
  type        = bool
  default     = true
}

# --- Drone ---
# Drone authenticates against Gitea with an OAuth2 application. Create it in
# Gitea after the first apply (Settings -> Applications, redirect URI
# https://drone.<base_domain>/login), then set these and apply again.

variable "drone_gitea_client_id" {
  description = "Client id of the Gitea OAuth2 application for Drone."
  type        = string
  default     = ""
}

variable "drone_gitea_client_secret" {
  description = "Client secret of the Gitea OAuth2 application for Drone."
  type        = string
  default     = ""
  sensitive   = true
}

variable "drone_rpc_secret" {
  description = "Shared secret between the Drone server and its runners."
  type        = string
  sensitive   = true
}

# --- Grafana ---

variable "grafana_namespace" {
  description = "Namespace for Grafana."
  type        = string
  default     = "grafana"
}

variable "grafana_admin_password" {
  description = "Admin password for Grafana."
  type        = string
  sensitive   = true
}

# --- Harbor ---

variable "harbor_namespace" {
  description = "Namespace for Harbor."
  type        = string
  default     = "harbor"
}

variable "harbor_external_url" {
  description = "URL clients use to reach Harbor. Empty: https://harbor.<base_domain>."
  type        = string
  default     = ""
}

variable "harbor_ipv6_enabled" {
  description = "Enable IPv6 in Harbor's nginx."
  type        = bool
  default     = false
}

# --- Postgres ---

variable "percona_postgres_namespace" {
  description = "Namespace for the Percona Postgres operator."
  type        = string
  default     = "percona-postgres"
}

variable "zalando_postgres_namespace" {
  description = "Namespace for the Zalando Postgres operator and its UI."
  type        = string
  default     = "zalando-postgres"
}

# --- Rustpad ---

variable "rustpad_namespace" {
  description = "Namespace for Rustpad."
  type        = string
  default     = "rustpad"
}

variable "rustpad_pvc_size" {
  description = "Size of the Rustpad data volume, in GiB."
  type        = number
  default     = 4
}

# --- Velero ---

variable "velero_credentials_secret" {
  description = "Contents of Velero's cloud credentials file (e.g. an AWS-style [default] profile for MinIO)."
  type        = string
  sensitive   = true
}

variable "velero_backup_storage_name" {
  description = "Name of Velero's BackupStorageLocation."
  type        = string
  default     = "backups"
}

variable "velero_backup_storage_provider" {
  description = "Provider plugin for the BackupStorageLocation."
  type        = string
  default     = "aws"
}

variable "velero_backup_storage_bucket" {
  description = "Bucket for the BackupStorageLocation."
  type        = string
  default     = "velero-backups"
}

variable "velero_backup_storage_region" {
  description = "Region for the BackupStorageLocation."
  type        = string
  default     = "us-east-1"
}

# --- Derived ---

locals {
  ssh_external_host   = var.ssh_external_host != "" ? var.ssh_external_host : "ssh.gitea.${var.base_domain}"
  harbor_external_url = var.harbor_external_url != "" ? var.harbor_external_url : "https://harbor.${var.base_domain}"
}
