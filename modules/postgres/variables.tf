# Namespace for Percona Postgres
variable "percona_postgres_namespace" {
  description = "The Kubernetes namespace where Percona Postgres will be deployed."
  type        = string
}

# Namespace for Zalando Postgres
variable "zalando_postgres_namespace" {
  description = "The Kubernetes namespace where Zalando Postgres will be deployed."
  type        = string
}

# Ingress class for Zalando Postgres UI
variable "zalando_postgres_ui_ingress_class" {
  description = "The ingress class to be used for Zalando Postgres UI."
  type        = string
}

# TLS secret name for Zalando Postgres UI
variable "zalando_postgres_ui_tls_secret_name" {
  description = "The name of the TLS secret for Zalando Postgres UI ingress."
  type        = string
}

# Ingress host for Zalando Postgres UI
variable "zalando_postgres_ui_ingress_host" {
  description = "The hostname for Zalando Postgres UI ingress."
  type        = string
}