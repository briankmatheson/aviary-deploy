# Namespace for Rustpad
variable "rustpad_namespace" {
  description = "The Kubernetes namespace where Rustpad will be deployed."
  type        = string
}

# Ingress class for Rustpad
variable "rustpad_ingress_class" {
  description = "The ingress class to be used for Rustpad."
  type        = string
}

# TLS secret name for Rustpad
variable "rustpad_tls_secret_name" {
  description = "The name of the TLS secret for Rustpad ingress."
  type        = string
}

# Ingress host for Rustpad
variable "rustpad_ingress_host" {
  description = "The hostname for Rustpad ingress."
  type        = string
}

variable "rustpad_pvc_size" {
  description = "The storage size for rustpad."
  type        = string
}
