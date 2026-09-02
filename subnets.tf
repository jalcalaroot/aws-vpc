# --------------------------------------------------------------------------
# Public tier: recursos con IP pública directa (ALB, bastion, etc.).
# --------------------------------------------------------------------------

resource "aws_subnet" "public" {
  count = var.az_count

  vpc_id            = aws_vpc.this.id
  cidr_block        = local.public_subnet_cidrs[count.index]
  availability_zone = local.azs[count.index]

  # Sin auto-asignación de IP pública: nada requiere hoy exposición directa.
  # Un recurso futuro que sí la necesite la pide explícitamente, en vez de
  # que cualquier cosa lanzada en la subnet quede pública por defecto.
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.name}-public-${local.azs[count.index]}"
    Tier = "public"
  }
}

# --------------------------------------------------------------------------
# Compute tier: app servers, contenedores, lo que corre la lógica de negocio.
# Sale a internet vía NAT Gateway, nunca directo.
# --------------------------------------------------------------------------

resource "aws_subnet" "compute" {
  count = var.az_count

  vpc_id            = aws_vpc.this.id
  cidr_block        = local.compute_subnet_cidrs[count.index]
  availability_zone = local.azs[count.index]

  tags = {
    Name = "${var.name}-compute-${local.azs[count.index]}"
    Tier = "compute"
  }
}

# --------------------------------------------------------------------------
# Data tier: bases de datos y almacenamiento. Sin salida a internet en
# absoluto (ver route_tables.tf) - defensa en profundidad independiente de
# los security groups, mismo criterio que el tier "data" del módulo de
# Azure (rt-data bloquea 0.0.0.0/0).
# --------------------------------------------------------------------------

resource "aws_subnet" "data" {
  count = var.az_count

  vpc_id            = aws_vpc.this.id
  cidr_block        = local.data_subnet_cidrs[count.index]
  availability_zone = local.azs[count.index]

  tags = {
    Name = "${var.name}-data-${local.azs[count.index]}"
    Tier = "data"
  }
}
