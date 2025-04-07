# Namespace for Rustpad
variable "rustpad_namespace" {
  description = "The Kubernetes namespace where Rustpad will be deployed."
  type        = string
  default     = "rustpad"
}

# Ingress class for Rustpad
variable "rustpad_ingress_class" {
  description = "The ingress class to be used for Rustpad."
  type        = string
  default     = "nginx"
}

# TLS secret name for Rustpad
variable "rustpad_tls_secret_name" {
  description = "The name of the TLS secret for Rustpad ingress."
  type        = string
  default     = "rustpad-tls"
}

# Ingress host for Rustpad
variable "rustpad_ingress_host" {
  description = "The hostname for Rustpad ingress."
  type        = string
  default     = "rustpad.local"
}