# MLflow Namespace
variable "mlflow_namespace" {
  description = "Namespace for MLflow"
  type        = string
  default     = "mlflow"
}

# MLflow Host
variable "mlflow_host" {
  description = "Host for MLflow ingress"
  type        = string
  default     = "mlflow.local"
}

# MLflow TLS Secret Name
variable "mlflow_tls_secret_name" {
  description = "TLS secret name for MLflow ingress"
  type        = string
  default     = "mlflow-tls"
}

# Ingress Class
variable "mlflow_ingress_class" {
  description = "Ingress class for MLflow"
  type        = string
  default     = "nginx"
}

# Cluster Issuer
variable "mlflow_cluster_issuer" {
  description = "Cluster issuer for MLflow"
  type        = string
  default     = "ca-issuer"
}