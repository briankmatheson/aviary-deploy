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
  minio_server   = "minio.local"
  minio_region   = "us-east-1"
  minio_user     = var.minio_user
  minio_password = var.minio_password
  minio_ssl      = true
}
