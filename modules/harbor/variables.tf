# Harbor Namespace
variable "harbor_namespace" {
  description = "Namespace for Harbor"
  type        = string
  default     = "harbor"
}

# Harbor Expose Type
variable "harbor_expose_type" {
  description = "Expose type for Harbor"
  type        = string
  default     = "ingress"
}

# Harbor Ingress Host
variable "harbor_ingress_host" {
  description = "Ingress host for Harbor"
  type        = string
  default     = "harbor.local"
}

# Harbor Ingress Class
variable "harbor_ingress_class" {
  description = "Ingress class for Harbor"
  type        = string
  default     = "nginx"
}

# Harbor External URL
variable "harbor_external_url" {
  description = "External URL for Harbor"
  type        = string
  default     = "https://harbor.local"
}

# Harbor IPv6 Enabled
variable "harbor_ipv6_enabled" {
  description = "Enable IPv6 for Harbor"
  type        = bool
  default     = false
}