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

# --- Gateway Endpoints (gratis) ---

resource "aws_vpc_endpoint" "s3" {
  count = var.enable_s3_endpoint ? 1 : 0

  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.compute.id, aws_route_table.data.id]

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

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name}-interface-endpoints"
  }
}
