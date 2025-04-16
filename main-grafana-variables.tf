# Define Namespace
variable "grafana_namespace" {
  description = "Namespace for Grafana"
  type        = string
}

# Define Credentials and Host Configuration
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

# Define Ingress Configurations
variable "ingress_class" {
  description = "Ingress class for Kubernetes"
  type        = string
  default     = "nginx"
}
variable "cluster_issuer" {
  description = "Cluster issuer for cert-manager"
  type        = string
}

# Local Values
locals {
  default_annotations = {
    "kubernetes.io/ingress.class" = var.ingress_class
  }
}
