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

variable "smtp_load_balancer_ip" {
  description = "LoadBalancer IP (from the cluster's LB pool) for Axigen's SMTP front end: ports 25, 465 and 587. bin/set-nat.sh forwards outside mail to it. Empty: SMTP stays in-cluster."
  type        = string
  default     = ""
}

variable "axigen_postmaster_password" {
  description = "Record of the postmaster password set by hand in Axigen (the chart derives the initial one from the admin password). Not applied by the stack."
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

variable "drone_db_password" {
  description = "Password of Drone's Postgres database. Setting it switches the Drone server to HA mode: drone_server_replicas pods sharing Postgres and Valkey instead of one pod on SQLite. Needs drone_valkey_password and drone_cookie_secret too."
  type        = string
  default     = ""
  sensitive   = true
}

variable "drone_valkey_password" {
  description = "Password of the Valkey the Drone servers coordinate through (HA mode)."
  type        = string
  default     = ""
  sensitive   = true
}

variable "drone_cookie_secret" {
  description = "Session-signing secret shared by every Drone server (HA mode), e.g. openssl rand -hex 32."
  type        = string
  default     = ""
  sensitive   = true
}

variable "drone_server_replicas" {
  description = "How many Drone server pods in HA mode (drone_db_password set). Without HA there is always one."
  type        = number
  default     = 3
}

variable "drone_runner_replicas" {
  description = "How many Drone runner pods. Each takes builds from the server independently."
  type        = number
  default     = 5
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

variable "dns_zones" {
  description = "Zones the aviary-dns CoreDNS is authoritative for: zone name => path of its zone file (e.g. ../dns/db.example.org). Empty: no DNS server."
  type        = map(string)
  default     = {}
}

variable "dns_replicas" {
  description = "CoreDNS replicas for dns_zones."
  type        = number
  default     = 3
}

variable "dns_memory" {
  description = "Memory request and limit of each dns_zones CoreDNS pod."
  type        = string
  default     = "512Mi"
}

variable "dns_image" {
  description = "CoreDNS image for dns_zones."
  type        = string
  default     = "registry.k8s.io/coredns/coredns:v1.14.6"
}

variable "jitsi_enabled" {
  description = "Deploy Jitsi Meet. Also needs jitsi_jvb_load_balancer_ip."
  type        = bool
  default     = false
}

variable "jitsi_chart_version" {
  description = "jitsi-meet Helm chart version."
  type        = string
  default     = "3.12.0"
}

variable "jitsi_jvb_load_balancer_ip" {
  description = "LoadBalancer IP (from the cluster's LB pool) for the Jitsi video bridge: UDP 10000. bin/set-nat.sh forwards outside media to it."
  type        = string
  default     = ""
}

variable "jitsi_public_ip" {
  description = "Public IP outside callers reach the video bridge on (the router's WAN address). Empty: Jitsi only works for callers that can reach the LoadBalancer IP."
  type        = string
  default     = ""
}

variable "jitsi_timezone" {
  description = "Time zone for the Jitsi containers."
  type        = string
  default     = "America/New_York"
}

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

# --- CloudBeaver ---

variable "cloudbeaver_admin_password" {
  description = "Password of CloudBeaver's administrator, set at its first start. Empty leaves CloudBeaver out (it would otherwise hand its setup wizard to the first visitor). At least 8 characters, with a letter and a digit."
  type        = string
  default     = ""
  sensitive   = true
}

variable "cloudbeaver_admin_user" {
  description = "Name of CloudBeaver's administrator."
  type        = string
  default     = "cbadmin"
}

variable "cloudbeaver_version" {
  description = "dbeaver/cloudbeaver image tag."
  type        = string
  default     = "26.2.4"
}

variable "cloudbeaver_pvc_size" {
  description = "Size of the CloudBeaver workspace volume, in GiB."
  type        = number
  default     = 2
}

# --- Garage ---

variable "garage_admin_token" {
  description = "Bearer token of Garage's admin API (e.g. openssl rand -hex 32). Empty leaves Garage out."
  type        = string
  default     = ""
  sensitive   = true
}

variable "garage_data_size" {
  description = "Size of each Garage node's data volume, in GiB (there are three, holding three copies)."
  type        = number
  default     = 20
}

# --- Logs ---

variable "loki_remote_url" {
  description = "Push URL of a Loki outside this cluster that gets a copy of every pod's logs, e.g. https://registry.mesh.<domain>/loki/api/v1/push for the one on the management cluster. Empty: logs stay in this cluster only."
  type        = string
  default     = ""
}

variable "loki_remote_user" {
  description = "Basic-auth user for loki_remote_url."
  type        = string
  default     = "logs"
}

variable "loki_remote_password" {
  description = "Basic-auth password for loki_remote_url."
  type        = string
  default     = ""
  sensitive   = true
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

variable "velero_backup_storage_s3_url" {
  description = "S3 endpoint for the BackupStorageLocation when it is not AWS, e.g. Garage's http://garage.<ns_prefix>garage.svc.cluster.local:3900 (with velero_backup_storage_region = \"garage\" and a Garage key in velero_credentials_secret). Empty: AWS."
  type        = string
  default     = ""
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

# --- Ollama / chat window ---

variable "ollama_enabled" {
  description = "Run Ollama on the GPU node (apps/ollama.tf) and point the landing page's chat window at it."
  type        = bool
  default     = false
}

variable "ollama_image" {
  description = "Ollama image."
  type        = string
  default     = "ollama/ollama:latest"
}

variable "aviary_chat_url" {
  description = "OpenAI-compatible API base for the landing page's chat window. Empty: the cluster's Ollama if ollama_enabled, else no chat window."
  type        = string
  default     = ""
}

variable "aviary_chat_model" {
  description = "Model the landing page's chat window talks to (must be pulled in Ollama)."
  type        = string
  default     = "llama3"
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
variable "aviary_anthropic_api_key" {
  description = "Anthropic API key for Claude in the landing page's whiteboard. Empty: Claude is not in the room. Replies are billed to this key, and what is said in the room is sent to Anthropic's API."
  type        = string
  default     = ""
  sensitive   = true
}
variable "aviary_claude_model" {
  description = "Claude model the whiteboard talks to."
  type        = string
  default     = "claude-opus-5-5"
}
variable "aviary_oauth_admin_only" {
  description = "Require the gitea user to be an admin to use the aviary landing page."
  type        = bool
  default     = false
}

# --- Aviary landing page settings (the AviaryConfig object) ---

variable "aviary_session_minutes" {
  description = "The landing page's idle timer: a sign-in runs out after this many minutes with nothing done (1-1440)."
  type        = number
  default     = 30
}

variable "aviary_session_max_minutes" {
  description = "The most a landing-page sign-in lasts from signing in, however active (5-10080). aviary_session_minutes is the idle timer within it."
  type        = number
  default     = 720
}

variable "aviary_scale_max_pods" {
  description = "The most pods the landing page's Scale popup will set on one workload (1-100)."
  type        = number
  default     = 10
}

variable "aviary_admin_team" {
  description = "A Gitea team, as org:team, whose members are admins on the landing page besides Gitea's site administrators. Empty: site administrators only."
  type        = string
  default     = ""
}

variable "aviary_chat_briefing" {
  description = "What the whiteboard's model is told about this place (up to 24000 characters). Empty: the page falls back to the briefing key of its aviary-chat ConfigMap."
  type        = string
  default     = ""
}
