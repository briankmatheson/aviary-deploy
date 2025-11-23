# Velero Helm Release Variables
variable "velero_credentials_secret" {
  description = "The secret contents for Velero credentials."
  type        = string
}

variable "velero_backup_storage_name" {
  description = "The name of the backup storage location for Velero."
  type        = string
}

variable "velero_backup_storage_provider" {
  description = "The provider for the backup storage location for Velero."
  type        = string
}

variable "velero_backup_storage_bucket" {
  description = "The bucket name for the backup storage location for Velero."
  type        = string
}

variable "velero_backup_storage_region" {
  description = "The region for the backup storage location for Velero."
  type        = string
}

