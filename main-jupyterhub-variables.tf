# JupyterHub Namespace
variable "jupyterhub_namespace" {
  description = "Namespace for JupyterHub"
  type        = string
}

# JupyterHub Host
variable "jupyterhub_host" {
  description = "Host for JupyterHub ingress"
  type        = string
}

# JupyterHub TLS Secret Name
variable "jupyterhub_tls_secret_name" {
  description = "TLS secret name for JupyterHub ingress"
  type        = string
}

# Ingress Class
variable "jupyterhub_ingress_class" {
  description = "Ingress class for JupyterHub"
  type        = string
}

# Cluster Issuer
variable "jupyterhub_cluster_issuer" {
  description = "Cluster issuer for JupyterHub"
  type        = string
}