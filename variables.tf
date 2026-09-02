variable "name" {
  description = "Prefijo de nombre para los recursos de la VPC"
  type        = string
}

variable "vpc_cidr" {
  description = "Bloque CIDR de la VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Cantidad de Availability Zones a cubrir (una subnet de cada tier por AZ)"
  type        = number
  default     = 3
}

variable "flow_logs_retention_days" {
  description = "Días de retención de los VPC Flow Logs en CloudWatch Logs"
  type        = number
  default     = 365
}

variable "enable_s3_endpoint" {
  description = "Crear un Gateway Endpoint a S3 (gratis - sin costo por hora ni por GB procesado) para que el tráfico a S3 desde compute/data no salga por el NAT Gateway"
  type        = bool
  default     = true
}

variable "enable_kms_endpoint" {
  description = "Crear un Interface Endpoint a KMS. Tiene costo real (~$0.01/hora por AZ + $0.01/GB procesado - con 3 AZs, ~$22/mes antes de tráfico) porque es un Interface Endpoint, no Gateway. Útil si algo en la VPC llama a la API de KMS seguido (cifrado de EBS, Secrets Manager, etc.) y querés que ese tráfico no salga por el NAT."
  type        = bool
  default     = true
}
