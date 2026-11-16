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
  default     = "briankmatheson/aviary-frontend:1.0.2"
}

# --- Gitea ---

variable "gitea_admin_password" {
  description = "Admin password for Gitea."
  type        = string
  sensitive   = true
}

variable "mattermost_db_password" {
  description = "Password for the Mattermost Postgres (cnpg) app user."
  type        = string
  sensitive   = true
}

# --- Axigen (AxiHelm) ---

variable "axigen_license_file" {
  description = "Path to the Axigen license (axigen_lk.bin). Empty: Axigen is not deployed."
  type        = string
  default     = ""
}

variable "axigen_mail_domain" {
  description = "Mail domain Axigen serves (user@<this>). Empty: base_domain. Changing it replaces the release."
  type        = string
  default     = ""
}

variable "axigen_cluster_key" {
  description = "Secret the Axigen nodes use for cluster synchronization. Required when Axigen is deployed."
  type        = string
  sensitive   = true
  default     = ""
}

variable "axigen_admin_password" {
  description = "Password for the Axigen admin account. Required when Axigen is deployed."
  type        = string
  sensitive   = true
  default     = ""
}

variable "axigen_timezone" {
  description = "Default time zone for new Axigen accounts."
  type        = string
  default     = "America/New_York"
}

variable "axigen_storage_size" {
  description = "Size of the Axigen backend's volume (mailboxes live here)."
  type        = string
  default     = "10Gi"
}

variable "kubewatch_mattermost_webhook" {
  description = "Mattermost incoming-webhook URL kubewatch posts cluster events to."
  type        = string
  sensitive   = true
  default     = ""
}

variable "kubewatch_mattermost_channel" {
  description = "Mattermost channel for kubewatch events (webhook's default if empty)."
  type        = string
  default     = "town-square"
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

variable "drone_admin_user" {
  description = "Gitea login that Drone creates as its admin on first start (needed to approve builds on protected repos and to manage secrets)."
  type        = string
  default     = "bmath"
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

variable "cnpg_namespace" {
  description = "Namespace for the CloudNativePG operator."
  type        = string
  default     = "cnpg-system"
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

variable "cluster_name" {
  description = "capi name of cluster"
  type        = string
}

variable "gateway_name" {
  description = "envoy gateway name"
  type        = string
  default     = "noname"
}

variable "gateway_namespace" {
  description = "envoy gateway namespace"
  type        = string
  default     = "envoy-gateway"
}

variable "nat_gateway_ip" {
  description = "Load-balancer IP for a second Gateway (aviary-nat) meant to be NATed to from outside. Must be in the cluster's LB pool. Empty: no second Gateway."
  type        = string
  default     = ""
}

variable "public_domain" {
  description = "Domain the public Gateway (nat_gateway_ip) serves the apps under: <app>.<public_domain>, the landing page at aviary.<public_domain>. Point a wildcard for it at the address that is NATed to nat_gateway_ip. Empty: the public Gateway serves the base_domain hostnames."
  type        = string
  default     = ""
}

variable "public_cluster_issuer" {
  description = "cert-manager ClusterIssuer for the public_domain certificates. Empty: a Let's Encrypt issuer (letsencrypt) this stack creates, solving HTTP-01 through the public Gateway."
  type        = string
  default     = ""
}

variable "cloudbeaver_admin_password" {
  description = "Initial admin password for CloudBeaver"
  type        = string
  sensitive   = true
}

variable "cloudbeaver_chart_path" {
  description = "Local path to the cloned dbeaver/cloudbeaver-deploy/k8s directory"
  type        = string
  default     = "./charts/cloudbeaver-deploy/k8s"
}

# --- Derived ---

locals {
  ssh_external_host   = var.ssh_external_host != "" ? var.ssh_external_host : "ssh.gitea.${var.base_domain}"
  harbor_external_url = var.harbor_external_url != "" ? var.harbor_external_url : "https://harbor.${var.base_domain}"
}

variable "ns_prefix" {
  description = "Prefix for every app namespace this project creates (RFC 1123: lowercase, no underscores). Empty = none."
  type        = string
  default     = "aviary-"
}

variable "aviary_oauth_client_id" {
  description = "OAuth2 client id (gitea application) for the aviary landing page login. Empty disables login."
  type        = string
  default     = ""
}
variable "aviary_oauth_client_secret" {
  description = "OAuth2 client secret for the aviary landing page."
  type        = string
  default     = ""
  sensitive   = true
}
variable "aviary_session_secret" {
  description = "Secret that signs the aviary landing page's session cookies."
  type        = string
  default     = ""
  sensitive   = true
}
variable "aviary_bypass_token" {
  description = "Shared token that bypasses aviary login (Authorization: Bearer, X-Aviary-Token, or ?token=), for automation."
  type        = string
  default     = ""
  sensitive   = true
}
variable "aviary_oauth_admin_only" {
  description = "Require the gitea user to be an admin to use the aviary landing page."
  type        = bool
  default     = false
}
