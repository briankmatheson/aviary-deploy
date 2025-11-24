variable "kubeconfig" {
  type        = string
  description = "Path to the Kubernetes configuration file."
}
variable "minio_user" {
  type        = string
  description = "Admin user."
}
variable "minio_password" {
  type        = string
  description = "Admin password."
}



