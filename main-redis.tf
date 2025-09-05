resource "helm_release" "redis" {
  name       = "redis"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "redis"
  namespace  = var.redis_namespace
  create_namespace = true

  set = [
    {
      name  = "auth.enabled"
      value = var.redis_auth_enabled
    },
    
    {
      name  = "architecture"
      value = var.redis_architecture
    }
  ]
}
  

