# MetalLB Variables
variable "metallb_ip_address_pool" {
  description = "The list of IP addresses for the MetalLB IP address pool."
  type        = list(string)
}

# NFS Storage Variables
variable "nfs_server" {
  description = "The NFS server address."
  type        = string
}

variable "nfs_share" {
  description = "The NFS share path."
  type        = string
}

# Ingress-NGINX Variables
variable "ingress_nginx_external_ip" {
  description = "The external IP address for the Ingress-NGINX service."
  type        = string
}

# Kubernetes Dashboard Variables
variable "dashboard_ingress_host" {
  description = "The hostname for the Kubernetes Dashboard ingress."
  type        = string
}

variable "dashboard_tls_secret_name" {
  description = "The TLS secret name for the Kubernetes Dashboard ingress."
  type        = string
}