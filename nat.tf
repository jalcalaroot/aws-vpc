# --------------------------------------------------------------------------
# Regional NAT Gateway (lanzado por AWS en nov-2025, ver
# https://aws.amazon.com/blogs/networking-and-content-delivery/introducing-amazon-vpc-regional-nat-gateway/)
#
# Reemplaza el patrón viejo de "un NAT Gateway zonal en una subnet pública,
# con riesgo de single point of failure si esa AZ cae". Un NAT Gateway
# regional es UN SOLO recurso que no vive en ninguna subnet - se asocia
# directo a la VPC y AWS expande/contrae automáticamente su cobertura de
# AZs según dónde detecta ENIs (auto mode, sin `availability_zone_address`
# blocks). Provisiona su propia EIP por AZ y su propia route table
# (`route_table_id`, con la ruta al Internet Gateway ya preconfigurada).
#
# No requiere subnet_id ni allocation_id (a diferencia del NAT zonal) - por
# eso este recurso no depende de aws_subnet.public.
# --------------------------------------------------------------------------

resource "aws_nat_gateway" "this" {
  vpc_id            = aws_vpc.this.id
  availability_mode = "regional"

  tags = {
    Name = "${var.name}-nat-regional"
  }

  depends_on = [aws_internet_gateway.this]
}
