# MinIO Namespace
variable "minio_namespace" {
  description = "Namespace for MinIO"
  type        = string
  default     = "minio"
}

# MinIO Host
variable "minio_host" {
  description = "Host for MinIO ingress"
  type        = string
  default     = "minio.local"
}

# MinIO TLS Secret Name
variable "minio_tls_secret_name" {
  description = "TLS secret name for MinIO ingress"
  type        = string
  default     = "minio-tls"
}

# Ingress Class
variable "minio_ingress_class" {
  description = "Ingress class for MinIO"
  type        = string
  default     = "nginx"
}

# Cluster Issuer
variable "minio_cluster_issuer" {
  description = "Cluster issuer for MinIO"
  type        = string
  default     = "ca-issuer"
}

# MinIO Root User
variable "minio_root_user" {
  description = "Root user for MinIO"
  type        = string
  default     = "minio"
}

# MinIO Root Password
variable "minio_root_password" {
  description = "Root password for MinIO"
  type        = string
  default     = "minio123"
}