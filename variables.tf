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
  description = "Cantidad de Availability Zones a usar (una subnet pública y una privada por AZ)"
  type        = number
  default     = 2
}

variable "flow_logs_retention_days" {
  description = "Días de retención de los VPC Flow Logs en CloudWatch Logs"
  type        = number
  default     = 365
}
