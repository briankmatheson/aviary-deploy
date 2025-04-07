# Velero Helm Release Variables
variable "velero_credentials_secret" {
  description = "The secret contents for Velero credentials."
  type        = string
  default = ""
}

variable "velero_backup_storage_name" {
  description = "The name of the backup storage location for Velero."
  type        = string
  default = ""
}

variable "velero_backup_storage_provider" {
  description = "The provider for the backup storage location for Velero."
  type        = string
  default = ""
}

variable "velero_backup_storage_bucket" {
  description = "The bucket name for the backup storage location for Velero."
  type        = string
  default = ""
}

variable "velero_backup_storage_region" {
  description = "The region for the backup storage location for Velero."
  type        = string
  default = ""
}

variable "velero_snapshot_location_name" {
  description = "The name of the volume snapshot location for Velero."
  type        = string
  default = ""
}

variable "velero_snapshot_location_provider" {
  description = "The provider for the volume snapshot location for Velero."
  type        = string
  default = ""
}

variable "velero_snapshot_location_region" {
  description = "The region for the volume snapshot location for Velero."
  type        = string
  default = ""
}

variable "velero_init_container_name" {
  description = "The name of the init container for Velero."
  type        = string
  default = ""
}

variable "velero_init_container_image" {
  description = "The image of the init container for Velero."
  type        = string
  default = ""
}

variable "velero_init_container_mount_path" {
  description = "The mount path for the init container for Velero."
  type        = string
  default = ""
}

variable "velero_init_container_volume_name" {
  description = "The volume name for the init container for Velero."
  type        = string
  default = ""
}