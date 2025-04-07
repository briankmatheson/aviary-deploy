# JupyterHub Namespace
variable "jupyterhub_namespace" {
  description = "Namespace for JupyterHub"
  type        = string
  default     = "jupyterhub"
}

# JupyterHub Host
variable "jupyterhub_host" {
  description = "Host for JupyterHub ingress"
  type        = string
  default     = "jupyterhub.local"
}

# JupyterHub TLS Secret Name
variable "jupyterhub_tls_secret_name" {
  description = "TLS secret name for JupyterHub ingress"
  type        = string
  default     = "jupyterhub-tls"
}

# Ingress Class
variable "jupyterhub_ingress_class" {
  description = "Ingress class for JupyterHub"
  type        = string
  default     = "nginx"
}

# Cluster Issuer
variable "jupyterhub_cluster_issuer" {
  description = "Cluster issuer for JupyterHub"
  type        = string
  default     = "ca-issuer"
}