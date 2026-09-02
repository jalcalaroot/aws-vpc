# VPC Encryption Controls (AWS, nov-2025):
# https://aws.amazon.com/blogs/aws/introducing-vpc-encryption-controls-enforce-encryption-in-transit-within-and-across-vpcs-in-a-region/
#
# Audita (monitor) o fuerza (enforce) cifrado en tránsito para tráfico
# dentro y entre VPCs en la región - el equivalente AWS a lo que
# azure-virtual-network resuelve con "VNet encryption" (ver ese módulo).
#
# Costo: gratis mientras la VPC esté vacía (sin recursos reales corriendo).
# En cuanto haya algo desplegado adentro, cobra una tarifa fija por hora por
# VPC (independiente del modo monitor/enforce) desde el 1-mar-2026 - el
# período de introducción gratuito ya terminó. Ver
# https://aws.amazon.com/about-aws/whats-new/2026/03/vpc-encryption-controls-pricing/
# para el detalle regional exacto.
#
# Default mode = "monitor": solo audita, no bloquea nada. "enforce" requiere
# decidir explícitamente qué excluir (NAT Gateway, Internet Gateway) porque
# el tráfico que sale a Internet no puede cifrarse por este mecanismo -
# forzarlo sin esas exclusiones rompería la salida a internet de compute.
resource "aws_vpc_encryption_control" "this" {
  count = var.enable_encryption_control ? 1 : 0

  vpc_id = aws_vpc.this.id
  mode   = var.encryption_control_mode

  # Solo aplican si mode = "enforce" - el tráfico hacia/desde Internet no
  # puede cifrarse por este mecanismo (solo cubre backbone AWS-a-AWS), así
  # que quedan excluidos para no romper la salida a internet de compute ni
  # el ingreso de public.
  nat_gateway_exclusion      = var.encryption_control_mode == "enforce" ? "enable" : "disable"
  internet_gateway_exclusion = var.encryption_control_mode == "enforce" ? "enable" : "disable"

  tags = {
    Name = "${var.name}-encryption-control"
  }
}
