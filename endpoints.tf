# --------------------------------------------------------------------------
# VPC Endpoints: mantener el tráfico a servicios AWS dentro del backbone de
# AWS en vez de salir por el NAT Gateway (o Internet en el caso de public) -
# reduce costo de NAT data processing y superficie de exposición.
# --------------------------------------------------------------------------

# S3: Gateway Endpoint, sin costo por hora ni por GB procesado - se asocia
# directo a las route tables (no ocupa IPs de subnet, no es una ENI).
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

# KMS: Interface Endpoint - SÍ tiene costo real (~$0.01/hora por AZ +
# $0.01/GB procesado, ver variables.tf). Un ENI por AZ en las subnets de
# compute; data también puede resolverlo (los Interface Endpoints son
# alcanzables desde toda la VPC, no solo desde la subnet donde vive el ENI),
# así que no hace falta duplicar ENIs en data.
resource "aws_vpc_endpoint" "kms" {
  count = var.enable_kms_endpoint ? 1 : 0

  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${data.aws_region.current.region}.kms"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.compute[*].id
  security_group_ids  = [aws_security_group.kms_endpoint[0].id]
  private_dns_enabled = true

  tags = {
    Name = "${var.name}-kms-endpoint"
  }
}

resource "aws_security_group" "kms_endpoint" {
  count = var.enable_kms_endpoint ? 1 : 0

  name        = "${var.name}-kms-endpoint"
  description = "Permite HTTPS desde toda la VPC hacia el Interface Endpoint de KMS"
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
    Name = "${var.name}-kms-endpoint"
  }
}

data "aws_region" "current" {}
