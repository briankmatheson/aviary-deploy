provider "helm" {
  kubernetes {
    config_path = "/home/bmath/k8s/q11/kubeconfig.yaml"
  }
}
provider "kubernetes" {
  config_path = var.kubeconfig
}
provider "kubectl" {
  load_config_file       = true
}
