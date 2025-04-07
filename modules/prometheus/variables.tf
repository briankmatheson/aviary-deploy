# Namespace for Prometheus
variable "prometheus_namespace" {
  description = "The Kubernetes namespace where Prometheus will be deployed."
  type        = string
  default     = "prometheus"
}

# Admin password for Prometheus
variable "prometheus_admin_password" {
  description = "The admin password for Prometheus."
  type        = string
  default     = "admin"
}