# Namespace for Redis
variable "redis_namespace" {
  description = "The Kubernetes namespace where Redis will be deployed."
  type        = string
  default = "redis"
}

# Enable or disable Redis authentication
variable "redis_auth_enabled" {
  description = "Specifies whether Redis authentication is enabled."
  type        = bool
  default = false
}

# Redis architecture
variable "redis_architecture" {
  description = "The architecture of the Redis deployment (e.g., standalone, cluster)."
  type        = string
  default = "standalone"
}