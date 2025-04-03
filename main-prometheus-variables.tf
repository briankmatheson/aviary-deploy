# Namespace for Prometheus
variable "prometheus_namespace" {
  description = "The Kubernetes namespace where Prometheus will be deployed."
  type        = string
}

# Admin password for Prometheus
variable "prometheus_admin_password" {
  description = "The admin password for Prometheus."
  type        = string
}