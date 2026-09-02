# --------------------------------------------------------------------------
# Transit tier: exclusivamente para el ENI del Transit Gateway attachment,
# nada más corre acá. Sigue las AWS Transit Gateway design best practices al
# pie de la letra:
#   - Subnet dedicada por AZ, /28 (16 IPs) - solo hace falta una IP para el
#     ENI del attachment, /28 deja margen sin desperdiciar espacio del /16.
#   - NACL abierta en ambos sentidos (ver nacl.tf) - AWS lo pide
#     explícitamente para no interferir con el routing del Transit Gateway.
#   - Mismo route table para todas las subnets de attachment (ver
#     route_tables.tf), sin rutas propias más allá de la local de VPC - el
#     ruteo hacia otras redes vía TGW se define en las route tables de las
#     subnets QUE CONSUMEN el attachment, no acá.
#
# Se sacan de un bloque separado del resto de los tiers (que usan /24) para
# no competir por espacio de direcciones con ellos.
# --------------------------------------------------------------------------

locals {
  transit_block        = cidrsubnet(var.vpc_cidr, 8, 250) # 10.0.250.0/24 con el vpc_cidr default
  transit_subnet_cidrs = [for i in range(var.az_count) : cidrsubnet(local.transit_block, 4, i)]
}

resource "aws_subnet" "transit" {
  count = var.az_count

  vpc_id            = aws_vpc.this.id
  cidr_block        = local.transit_subnet_cidrs[count.index]
  availability_zone = local.azs[count.index]

  tags = {
    Name = "${var.name}-transit-${local.azs[count.index]}"
    Tier = "transit"
  }
}
