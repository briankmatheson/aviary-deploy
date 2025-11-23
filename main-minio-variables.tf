 # MinIO Namespace
variable "minio_namespace" {
  description = "Namespace for MinIO"
  type        = string
}

# MinIO Host
variable "minio_host" {
  description = "Host for MinIO ingress"
  type        = string
}

# MinIO TLS Secret Name
variable "minio_tls_secret_name" {
  description = "TLS secret name for MinIO ingress"
  type        = string
}

# Ingress Class
variable "minio_ingress_class" {
  description = "Ingress class for MinIO"
  type        = string
}

# Cluster Issuer
variable "minio_cluster_issuer" {
  description = "Cluster issuer for MinIO"
  type        = string
}

# MinIO Root User
variable "minio_root_user" {
  description = "Root user for MinIO"
  type        = string
}

# MinIO Root Password
variable "minio_root_password" {
  description = "Root password for MinIO"
  type        = string
}
variable "minio_velero_access" {
  description = "username"
  type        = string
}

variable "minio_velero_secret" {
  description = "password"
  type        = string
}


