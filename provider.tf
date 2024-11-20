provider "helm" {
  kubernetes {
    config_path = "/home/bmath/k8s/u99/kubeconfig.yaml"
  }
}
provider "kubernetes" {
  config_path = var.kubeconfig
}
provider "kubectl" {
  load_config_file       = true
}
