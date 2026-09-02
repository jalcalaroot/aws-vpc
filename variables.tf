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

variable "enable_dynamodb_endpoint" {
  description = "Crear un Gateway Endpoint a DynamoDB (gratis, igual que S3)"
  type        = bool
  default     = true
}

# --- Interface Endpoints: cada uno ronda ~$22/mes (3 AZs x ~$0.01/hora) +
# $0.01/GB procesado, ANTES de cualquier tráfico. Si activás los 5 grupos de
# abajo (kms, ssm x3, secretsmanager, logs, sts = 7 endpoints), son
# ~$154/mes solo en cargo por hora. Apagá los que no uses todavía. ---

variable "enable_kms_endpoint" {
  description = "Interface Endpoint a KMS (~$22/mes, 3 AZs). Útil si algo en la VPC llama seguido a la API de KMS (cifrado de EBS, Secrets Manager, etc.)."
  type        = bool
  default     = true
}

variable "enable_ssm_endpoints" {
  description = "Interface Endpoints a SSM + SSM Messages + EC2 Messages (~$66/mes, 3 endpoints x 3 AZs). Habilita Session Manager - acceso a instancias EC2 en subnets privadas sin bastion host ni SSH expuesto. El trío completo es obligatorio para que Session Manager funcione (no alcanza con activar solo uno)."
  type        = bool
  default     = true
}

variable "enable_secretsmanager_endpoint" {
  description = "Interface Endpoint a Secrets Manager (~$22/mes, 3 AZs). Para apps/DBs que leen credenciales desde ahí sin salir por el NAT."
  type        = bool
  default     = true
}

variable "enable_cloudwatch_logs_endpoint" {
  description = "Interface Endpoint a CloudWatch Logs (~$22/mes, 3 AZs). Para que apps en compute logueen a CloudWatch sin salir por el NAT (los VPC Flow Logs de este módulo NO lo necesitan - los publica el propio plano de AWS, no una instancia dentro de la VPC)."
  type        = bool
  default     = true
}

variable "enable_sts_endpoint" {
  description = "Interface Endpoint a STS (~$22/mes, 3 AZs). Para sts:AssumeRole sin salir por el NAT - común quan se usan roles IAM desde dentro de la VPC (a menudo junto con SSM)."
  type        = bool
  default     = true
}

# --- VPC Encryption Controls (lanzado nov-2025) ---

variable "enable_encryption_control" {
  description = "Crear un aws_vpc_encryption_control para esta VPC (auditar/forzar cifrado en tránsito dentro y entre VPCs). Gratis mientras la VPC esté vacía (sin recursos reales corriendo) - empieza a cobrar una tarifa fija por hora en cuanto haya algo desplegado adentro. Ver README para el detalle de precio y de qué tráfico cubre."
  type        = bool
  default     = true
}

variable "encryption_control_mode" {
  description = "monitor (solo audita, cero riesgo de bloquear tráfico) o enforce (bloquea tráfico no cifrado - requiere revisar exclusiones para NAT Gateway/Internet Gateway antes de activarlo, ya que el tráfico hacia internet no puede cifrarse por este mecanismo)"
  type        = string
  default     = "monitor"

  validation {
    condition     = contains(["monitor", "enforce"], var.encryption_control_mode)
    error_message = "encryption_control_mode debe ser \"monitor\" o \"enforce\"."
  }
}
