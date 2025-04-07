# MetalLB Variables
variable "metallb_ip_address_pool" {
  description = "The list of IP addresses for the MetalLB IP address pool."
  type        = list(string)
  default     = [
    "192.168.122.6/32",
    "192.168.122.7/32",
    "192.168.122.8/32",
    "192.168.122.9/32"
  ]
}

# NFS Storage Variables
variable "nfs_server" {
  description = "The NFS server address."
  type        = string
  default     = "192.168.122.5"
}

variable "nfs_share" {
  description = "The NFS share path."
  type        = string
  default     = "/export"
}

# Ingress-NGINX Variables
variable "ingress_nginx_external_ip" {
  description = "The external IP address for the Ingress-NGINX service."
  type        = string
  default     = "192.168.122.6"
}

# Kubernetes Dashboard Variables
variable "dashboard_ingress_host" {
  description = "The hostname for the Kubernetes Dashboard ingress."
  type        = string
  default     = "kubernetes-dashboard.local"
}

variable "dashboard_tls_secret_name" {
  description = "The TLS secret name for the Kubernetes Dashboard ingress."
  type        = string
  default     = "kubernetes-dashboard-tls"
}