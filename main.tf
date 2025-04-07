module "certmanager" {
  source = "./modules/certmanager"
}

module "gitea" {
  source = "./modules/gitea"
}

module "grafana" {
  source = "./modules/grafana"
}

module "harbor" {
  source = "./modules/harbor"
}

module "jupyterhub" {
  source = "./modules/jupyterhub"
}

module "minio" {
  source = "./modules/minio"
}

module "mlflow" {
  source = "./modules/mlflow"
}

module "postgres" {
  source = "./modules/postgres"
}

module "prometheus" {
  source = "./modules/prometheus"
}

module "redis" {
  source = "./modules/redis"
}

module "rustpad" {
  source = "./modules/rustpad"
}

module "system" {
  source = "./modules/system"
}

module "velero" {
  source = "./modules/velero"
}