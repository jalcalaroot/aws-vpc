# --------------------------------------------------------------------------
# Network ACLs: segunda capa de defensa a nivel subnet, además de los
# security groups que cada consumidor cree para sus propios recursos (este
# módulo no crea SGs de workload, solo restringe el default - ver main.tf).
# NACLs son stateless (a diferencia de los SGs), así que cada regla necesita
# su contraparte explícita en el sentido opuesto.
#
# Tres NACLs, no cuatro: compute y data comparten una NACL "privada" (mismo
# alcance permisivo a nivel de subnet que ya cubren los security groups -
# el enforcement fino vive en los SGs, no acá). Transit tiene la suya propia
# porque AWS pide explícitamente que quede abierta en ambos sentidos para
# no interferir con el Transit Gateway - ver subnets_transit.tf.
# --------------------------------------------------------------------------

# --- Pública: solo 80/443 desde Internet + ephemeral de retorno ---

resource "aws_network_acl" "public" {
  #checkov:skip=CKV2_AWS_1:falso positivo - subnet_ids se resuelve vía splat (aws_subnet.public[*].id), Checkov no sigue esa expresión en su grafo pero la asociación es real (verificar con `aws ec2 describe-network-acls`).
  vpc_id     = aws_vpc.this.id
  subnet_ids = aws_subnet.public[*].id

  tags = {
    Name = "${var.name}-public"
  }
}

resource "aws_network_acl_rule" "public_in_https" {
  network_acl_id = aws_network_acl.public.id
  rule_number    = 100
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}

resource "aws_network_acl_rule" "public_in_http" {
  network_acl_id = aws_network_acl.public.id
  rule_number    = 110
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 80
  to_port        = 80
}

resource "aws_network_acl_rule" "public_in_ephemeral" {
  #checkov:skip=CKV_AWS_231:rango ephemeral de retorno (1024-65535), no una regla de acceso a RDP - Checkov marca falso positivo por solapar con el puerto 3389.
  network_acl_id = aws_network_acl.public.id
  rule_number    = 120
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

resource "aws_network_acl_rule" "public_out_https" {
  network_acl_id = aws_network_acl.public.id
  rule_number    = 100
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}

resource "aws_network_acl_rule" "public_out_http" {
  network_acl_id = aws_network_acl.public.id
  rule_number    = 110
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 80
  to_port        = 80
}

resource "aws_network_acl_rule" "public_out_ephemeral" {
  network_acl_id = aws_network_acl.public.id
  rule_number    = 120
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

# --- Privada (compute + data): todo el tráfico intra-VPC + salida general a
# internet vía NAT (data igual queda aislada a nivel de ruteo, ver
# route_tables.tf - esto solo evita que la NACL sea más restrictiva de lo
# que ya hacen los security groups) ---

resource "aws_network_acl" "private" {
  #checkov:skip=CKV2_AWS_1:falso positivo - mismo caso que aws_network_acl.public, subnet_ids vía concat()+splat no lo sigue el grafo de Checkov.
  vpc_id     = aws_vpc.this.id
  subnet_ids = concat(aws_subnet.compute[*].id, aws_subnet.data[*].id)

  tags = {
    Name = "${var.name}-private"
  }
}

resource "aws_network_acl_rule" "private_in_vpc" {
  #checkov:skip=CKV_AWS_352:por diseño - la NACL privada es deliberadamente permisiva intra-VPC (el enforcement fino vive en los security groups de cada consumidor, ver el comentario de diseño al inicio de este archivo).
  network_acl_id = aws_network_acl.private.id
  rule_number    = 100
  egress         = false
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = var.vpc_cidr
  from_port      = 0
  to_port        = 0
}

resource "aws_network_acl_rule" "private_in_ephemeral" {
  #checkov:skip=CKV_AWS_231:rango ephemeral de retorno (1024-65535), no una regla de acceso a RDP - mismo falso positivo que public_in_ephemeral.
  network_acl_id = aws_network_acl.private.id
  rule_number    = 110
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

resource "aws_network_acl_rule" "private_out_vpc" {
  network_acl_id = aws_network_acl.private.id
  rule_number    = 100
  egress         = true
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = var.vpc_cidr
  from_port      = 0
  to_port        = 0
}

resource "aws_network_acl_rule" "private_out_https" {
  network_acl_id = aws_network_acl.private.id
  rule_number    = 110
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}

resource "aws_network_acl_rule" "private_out_http" {
  network_acl_id = aws_network_acl.private.id
  rule_number    = 120
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 80
  to_port        = 80
}

# --- Transit: abierta en ambos sentidos, requisito explícito de AWS para
# subnets de Transit Gateway attachment (ver subnets_transit.tf) ---

resource "aws_network_acl" "transit" {
  #checkov:skip=CKV2_AWS_1:falso positivo - mismo caso que aws_network_acl.public, subnet_ids vía splat no lo sigue el grafo de Checkov.
  vpc_id     = aws_vpc.this.id
  subnet_ids = aws_subnet.transit[*].id

  tags = {
    Name = "${var.name}-transit"
  }
}

resource "aws_network_acl_rule" "transit_in_all" {
  #checkov:skip=CKV_AWS_229:por diseño - AWS pide explícitamente que las subnets de Transit Gateway attachment queden abiertas en ambos sentidos, ver comentario de diseño al inicio de este archivo y subnets_transit.tf.
  #checkov:skip=CKV_AWS_230:por diseño - mismo motivo que CKV_AWS_229.
  #checkov:skip=CKV_AWS_231:por diseño - mismo motivo que CKV_AWS_229.
  #checkov:skip=CKV_AWS_232:por diseño - mismo motivo que CKV_AWS_229.
  #checkov:skip=CKV_AWS_352:por diseño - mismo motivo que CKV_AWS_229.
  network_acl_id = aws_network_acl.transit.id
  rule_number    = 100
  egress         = false
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 0
  to_port        = 0
}

resource "aws_network_acl_rule" "transit_out_all" {
  network_acl_id = aws_network_acl.transit.id
  rule_number    = 100
  egress         = true
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 0
  to_port        = 0
}
