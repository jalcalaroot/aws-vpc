# --------------------------------------------------------------------------
# VPC Endpoints: mantener el tráfico a servicios AWS dentro del backbone de
# AWS en vez de salir por el NAT Gateway (o Internet en el caso de public) -
# reduce costo de NAT data processing y superficie de exposición.
#
# Dos tipos:
#   - Gateway (S3, DynamoDB): gratis, se asocian a route tables, no ocupan
#     IPs ni ENIs.
#   - Interface (todo el resto): ~$0.01/hora POR AZ + $0.01/GB procesado.
#     Con 3 AZs, cada Interface Endpoint ronda ~$22/mes antes de tráfico.
#     Cada uno es togglable por variable - ver variables.tf para el costo
#     acumulado si se activan todos.
# --------------------------------------------------------------------------

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# Política por defecto para todos los VPC Endpoints de este módulo: permite
# todo (no restringe acciones/recursos específicos, ya que es un módulo
# genérico que no sabe de antemano qué buckets/roles/tablas se van a usar),
# pero exige que el principal que llama pertenezca a esta misma cuenta AWS -
# guardrail estándar recomendado por AWS para evitar que credenciales
# comprometidas dentro de la VPC exfiltren datos hacia recursos de una
# cuenta ajena (ver "Limit access to Amazon S3 buckets owned by specific AWS
# accounts", AWS Storage Blog). Es un guardrail (techo de permisos), no un
# grant - no otorga acceso por sí sola, solo acota lo que el IAM del llamador
# ya permite.
data "aws_iam_policy_document" "endpoint_same_account_only" {
  #checkov:skip=CKV_AWS_49:falso positivo - esto es una VPC Endpoint Policy (un techo/guardrail sobre qué principal puede USAR el endpoint), no una policy IAM de identidad que otorga permisos. actions=["*"] acá es intencional: el endpoint no debe restringir QUÉ se puede hacer (eso ya lo controla el IAM del principal que llama), solo DESDE QUÉ CUENTA se puede llamar.
  #checkov:skip=CKV_AWS_1:mismo motivo que CKV_AWS_49 - este check está pensado para policies de identidad/recurso, no para VPC Endpoint Policies.
  #checkov:skip=CKV2_AWS_40:mismo motivo que CKV_AWS_49 - no es una policy IAM de identidad, es un guardrail de VPC Endpoint condicionado a aws:PrincipalAccount.
  statement {
    sid       = "RestrictToOwnAccount"
    effect    = "Allow"
    actions   = ["*"]
    resources = ["*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:PrincipalAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

# --- Gateway Endpoints (gratis) ---

resource "aws_vpc_endpoint" "s3" {
  count = var.enable_s3_endpoint ? 1 : 0

  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.compute.id, aws_route_table.data.id]
  policy            = data.aws_iam_policy_document.endpoint_same_account_only.json

  tags = {
    Name = "${var.name}-s3-endpoint"
  }
}

resource "aws_vpc_endpoint" "dynamodb" {
  count = var.enable_dynamodb_endpoint ? 1 : 0

  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.region}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.compute.id, aws_route_table.data.id]
  policy            = data.aws_iam_policy_document.endpoint_same_account_only.json

  tags = {
    Name = "${var.name}-dynamodb-endpoint"
  }
}

# --- Interface Endpoints (costo real - ver comentario arriba) ---
#
# Todos comparten un solo security group (HTTPS desde toda la VPC) y viven
# en las subnets de compute - un Interface Endpoint es alcanzable desde toda
# la VPC, no solo desde la subnet donde vive el ENI, así que no hace falta
# duplicar ENIs en data ni en las otras tiers.

locals {
  interface_endpoints = {
    kms            = var.enable_kms_endpoint
    ssm            = var.enable_ssm_endpoints
    ssmmessages    = var.enable_ssm_endpoints
    ec2messages    = var.enable_ssm_endpoints
    secretsmanager = var.enable_secretsmanager_endpoint
    logs           = var.enable_cloudwatch_logs_endpoint
    sts            = var.enable_sts_endpoint
  }
}

resource "aws_vpc_endpoint" "interface" {
  for_each = { for k, v in local.interface_endpoints : k => v if v }

  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${data.aws_region.current.region}.${each.key}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.compute[*].id
  security_group_ids  = [aws_security_group.interface_endpoints.id]
  private_dns_enabled = true
  # Mismo guardrail same-account-only que los Gateway endpoints. Ojo si se
  # activa enable_sts_endpoint junto con un caso de uso real de
  # sts:AssumeRole hacia OTRA cuenta AWS (p.ej. asumir un rol en una cuenta
  # de seguridad/logging centralizada) - esta política lo bloquearía. Si se
  # necesita eso, pasar un `policy` distinto (o null para acceso completo)
  # al desplegar, no cambiar el default de este módulo.
  policy = data.aws_iam_policy_document.endpoint_same_account_only.json

  tags = {
    Name = "${var.name}-${each.key}-endpoint"
  }
}

resource "aws_security_group" "interface_endpoints" {
  name        = "${var.name}-interface-endpoints"
  description = "Permite HTTPS desde toda la VPC hacia los Interface Endpoints (KMS, SSM, Secrets Manager, CloudWatch Logs, STS)"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "HTTPS desde la VPC"
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = [var.vpc_cidr]
  }

  # Los ENIs de Interface Endpoint solo responden a clientes dentro de la
  # VPC, nunca inician tráfico hacia Internet - egress se limita al CIDR
  # de la VPC en vez de 0.0.0.0/0.
  egress {
    description = "Respuesta HTTPS hacia la VPC"
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = [var.vpc_cidr]
  }

  tags = {
    Name = "${var.name}-interface-endpoints"
  }
}
