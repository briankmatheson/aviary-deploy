# Grafana Namespace
variable "grafana_namespace" {
  description = "Namespace for Grafana"
  type        = string
}

# Grafana Admin Password
variable "grafana_admin_password" {
  description = "Admin password for Grafana"
  type        = string
}

# Grafana Host
variable "grafana_host" {
  description = "Host for Grafana ingress"
  type        = string
}

# Grafana TLS Secret Name
variable "grafana_tls_secret_name" {
  description = "TLS secret name for Grafana ingress"
  type        = string
}

# Ingress Class
variable "ingress_class" {
  description = "Ingress class for Kubernetes"
  type        = string
}

# Cluster Issuer
variable "cluster_issuer" {
  description = "Cluster issuer for cert-manager"
  type        = string
}