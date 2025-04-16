# Gitea Namespace
variable "gitea_namespace" {
  description = "Namespace Gitea"
  type        = string
  default     = "gitea"
}

# Gitea Admin Password
variable "gitea_admin_password" {
  description = "Admin password for Gitea"
  type        = string
}

# Global Storage Class
variable "global_storage_class" {
  description = "Global storage class for Gitea"
  type        = string
  default     = "standard"
}

# Host Aliases
variable "host_aliases" {
  description = "Hostname aliases for Gitea"
  type        = list(object({
    ip        = string
    hostnames = list(string)
  }))
}

# SSH External Host
variable "ssh_external_host" {
  description = "External SSH hostname for Gitea"
  type        = string
}

# SSH Load Balancer IP
variable "ssh_load_balancer_ip" {
  description = "Load balancer IP for SSH"
  type        = string
}

# Ingress Hosts
variable "ingress_hosts" {
  description = "Ingress hostnames for Gitea"
  type        = list(string)
}

# Redis Enabled
variable "redis_enabled" {
  description = "Enable Redis for Gitea"
  type        = bool
  default     = true
}

# PostgreSQL Enabled
variable "postgresql_enabled" {
  description = "Enable PostgreSQL for Gitea"
  type        = bool
  default     = true
}

