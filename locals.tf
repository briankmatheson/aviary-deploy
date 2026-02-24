locals {
  default_annotations = {
    "kubernetes.io/ingress.class" = var.ingress_class
  }
}
