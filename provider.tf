provider "helm" {
  kubernetes {
    config_path = var.kubeconfig
  }
}
provider "kubernetes" {
  config_path = var.kubeconfig
}
provider "kubectl" {
  load_config_file = true
}
