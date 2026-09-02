# --------------------------------------------------------------------------
# Public: salida directa a Internet vía Internet Gateway.
# --------------------------------------------------------------------------

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "${var.name}-public"
  }
}

resource "aws_route_table_association" "public" {
  count = var.az_count

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# --------------------------------------------------------------------------
# Compute: salida a Internet vía el NAT Gateway regional (nunca directo).
# --------------------------------------------------------------------------

resource "aws_route_table" "compute" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
  }

  tags = {
    Name = "${var.name}-compute"
  }
}

resource "aws_route_table_association" "compute" {
  count = var.az_count

  subnet_id      = aws_subnet.compute[count.index].id
  route_table_id = aws_route_table.compute.id
}

# --------------------------------------------------------------------------
# Data: SIN ruta 0.0.0.0/0 - ni Internet Gateway ni NAT Gateway. Egreso a
# internet completamente bloqueado a nivel de ruteo, defensa en profundidad
# independiente de los security groups. Mismo criterio que rt-data en el
# módulo de Azure (azure-virtual-network), que bloquea 0.0.0.0/0 con
# next_hop_type = "None".
# --------------------------------------------------------------------------

resource "aws_route_table" "data" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name}-data"
  }
}

resource "aws_route_table_association" "data" {
  count = var.az_count

  subnet_id      = aws_subnet.data[count.index].id
  route_table_id = aws_route_table.data.id
}

# --------------------------------------------------------------------------
# Transit: sin rutas propias más allá de la local de VPC (implícita en toda
# route table). El ruteo hacia otras redes vía Transit Gateway se agrega en
# las route tables de las subnets QUE CONSUMEN el attachment (compute/data
# de este u otros VPCs), no en la subnet del attachment en sí - así lo
# documenta AWS explícitamente.
# --------------------------------------------------------------------------

resource "aws_route_table" "transit" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name}-transit"
  }
}

resource "aws_route_table_association" "transit" {
  count = var.az_count

  subnet_id      = aws_subnet.transit[count.index].id
  route_table_id = aws_route_table.transit.id
}
