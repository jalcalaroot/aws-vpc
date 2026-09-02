output "vpc_id" {
  value = aws_vpc.this.id
}

output "vpc_cidr" {
  value = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "compute_subnet_ids" {
  value = aws_subnet.compute[*].id
}

output "data_subnet_ids" {
  value = aws_subnet.data[*].id
}

output "transit_subnet_ids" {
  description = "Para usar como subnet_ids del Transit Gateway VPC attachment"
  value       = aws_subnet.transit[*].id
}

output "nat_gateway_id" {
  value = aws_nat_gateway.this.id
}

output "nat_gateway_route_table_id" {
  description = "Route table auto-creada por el NAT Gateway regional (trae la ruta al Internet Gateway preconfigurada)"
  value       = aws_nat_gateway.this.route_table_id
}

output "public_network_acl_id" {
  value = aws_network_acl.public.id
}

output "private_network_acl_id" {
  value = aws_network_acl.private.id
}

output "transit_network_acl_id" {
  value = aws_network_acl.transit.id
}

output "s3_vpc_endpoint_id" {
  value = var.enable_s3_endpoint ? aws_vpc_endpoint.s3[0].id : null
}

output "dynamodb_vpc_endpoint_id" {
  value = var.enable_dynamodb_endpoint ? aws_vpc_endpoint.dynamodb[0].id : null
}

output "interface_vpc_endpoint_ids" {
  description = "Map de servicio -> endpoint id, para los Interface Endpoints activos (kms, ssm, ssmmessages, ec2messages, secretsmanager, logs, sts)"
  value       = { for k, ep in aws_vpc_endpoint.interface : k => ep.id }
}

output "encryption_control_id" {
  value = var.enable_encryption_control ? aws_vpc_encryption_control.this[0].id : null
}
