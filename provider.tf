provider "helm" {
  kubernetes = {
    config_path = var.kubeconfig
  }
}
provider "kubernetes" {
  config_path = var.kubeconfig
}
provider "kubectl" {
  load_config_file = true
  config_path = var.kubeconfig
}
provider "minio" {
  minio_server   = "minio"
  minio_user     = "${var.minio_velero_access}"
  minio_password = "${var.minio_velero_secret}"
  minio_region   = "minio"
  minio_ssl      = true
}

