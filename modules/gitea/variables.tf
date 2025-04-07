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
  default     = "rrrrrrrr"
}

# Global Storage Class
variable "global_storage_class" {
  description = "Global storage class for Gitea"
  type        = string
  default     = "standard"
}

# Host Aliases
variable "host_aliases" {
  description = "Host aliases for Gitea"
  type        = list(object({
    ip        = string
    hostnames = list(string)
  }))
  default = [
    { ip = "192.168.122.7", hostnames = ["gitea"] },
    { ip = "192.168.122.9", hostnames = ["ssh.gitea.local"] }
  ]
}

# SSH External Host
variable "ssh_external_host" {
  description = "External SSH host for Gitea"
  type        = string
  default     = "ssh.gitea.local"
}

# SSH Load Balancer IP
variable "ssh_load_balancer_ip" {
  description = "Load balancer IP for SSH"
  type        = string
  default     = "192.168.122.9"
}

# Ingress Hosts
variable "ingress_hosts" {
  description = "Ingress hosts for Gitea"
  type        = list(string)
  default     = ["gitea", "gitea.local", "ssh.gitea.local"]
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