# Namespace for Redis
variable "redis_namespace" {
  description = "The Kubernetes namespace where Redis will be deployed."
  type        = string
}

# Enable or disable Redis authentication
variable "redis_auth_enabled" {
  description = "Specifies whether Redis authentication is enabled."
  type        = bool
}

# Redis architecture
variable "redis_architecture" {
  description = "The architecture of the Redis deployment (standalone|replication)."
  type        = string
}
