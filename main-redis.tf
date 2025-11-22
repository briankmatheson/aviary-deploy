resource "helm_release" "redis" {
  name       = "redis"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "redis"
  namespace  = var.redis_namespace
  create_namespace = true
  
 values = [
    <<EOF
     auth.enabled: var.redis_auth_enabled
     architecture: standalone
EOF
 ]
}


