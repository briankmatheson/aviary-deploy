module "certmanager" {
  source = "./modules/certmanager"
}

module "gitea" {
  source = "./modules/gitea"
  depends_on = [
    module.redis,
    module.postgres,
  ]
}

module "grafana" {
  source = "./modules/grafana"
  depends_on = [
    module.prometheus,
  ]
}

module "harbor" {
  source = "./modules/harbor"
  depends_on = [
    module.system,
  ]
}

module "jupyterhub" {
  source = "./modules/jupyterhub"
  depends_on = [
    module.system,
  ]
}

module "minio" {
  source = "./modules/minio"
  depends_on = [
    module.system,
  ]
}

module "mlflow" {
  source = "./modules/mlflow"
  depends_on = [
    module.system,
  ]
}

module "postgres" {
  source = "./modules/postgres"
  depends_on = [
    module.system,
  ]
}

module "prometheus" {
  source = "./modules/prometheus"
  depends_on = [
    module.system,
  ]
}

module "redis" {
  source = "./modules/redis"
}

module "rustpad" {
  source = "./modules/rustpad"
  depends_on = [
    module.system,
  ]
}

module "system" {
  source = "./modules/system"
  depends_on = [
    module.certmanager,
  ]
}

module "velero" {
  source = "./modules/velero"
  depends_on = [
    module.system,
  ]
}