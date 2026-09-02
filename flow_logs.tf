# --- VPC Flow Logs -> CloudWatch Logs (nunca S3 - se quiere consulta en
# tiempo real vía CloudWatch Logs Insights, no solo archivo para análisis
# batch) ---

resource "aws_cloudwatch_log_group" "flow_logs" {
  #checkov:skip=CKV_AWS_158:cifrado con CMK propia añade una KMS key ($1/mes + $0.03/10k requests) solo para logs de un ambiente de aprendizaje; el cifrado en reposo con la key administrada por AWS (aws/logs, gratis) ya aplica por defecto a todo log group de CloudWatch. Decisión explícita, no un descuido - revisar para prod.
  name              = "/${var.name}/vpc-flow-logs"
  retention_in_days = var.flow_logs_retention_days
}

data "aws_iam_policy_document" "flow_logs_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "flow_logs" {
  name               = "${var.name}-vpc-flow-logs"
  assume_role_policy = data.aws_iam_policy_document.flow_logs_assume_role.json
}

data "aws_iam_policy_document" "flow_logs_publish" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
    ]
    resources = ["${aws_cloudwatch_log_group.flow_logs.arn}:*"]
  }
}

resource "aws_iam_role_policy" "flow_logs_publish" {
  name   = "${var.name}-vpc-flow-logs-publish"
  role   = aws_iam_role.flow_logs.id
  policy = data.aws_iam_policy_document.flow_logs_publish.json
}

resource "aws_flow_log" "this" {
  vpc_id               = aws_vpc.this.id
  traffic_type         = "ALL"
  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.flow_logs.arn
  iam_role_arn         = aws_iam_role.flow_logs.arn

  # Formato enriquecido (v5) en vez del default v2 - agrega vpc-id/subnet-id/
  # instance-id (útil filtrando por tier en un solo VPC), tcp-flags (detecta
  # intentos de SYN scan), pkt-srcaddr/pkt-dstaddr (la IP real detrás de un
  # NAT Gateway o Interface Endpoint - srcaddr/dstaddr solo, no alcanza para
  # rastrear origen/destino real de tráfico que pasa por esos), y
  # region/az-id/flow-direction/traffic-path para diferenciar tráfico que
  # sale por IGW vs NAT vs peering. Costo marginal (más bytes por línea de
  # log), beneficio de investigación real.
  log_format = "$${version} $${account-id} $${vpc-id} $${subnet-id} $${instance-id} $${interface-id} $${srcaddr} $${dstaddr} $${srcport} $${dstport} $${protocol} $${packets} $${bytes} $${start} $${end} $${action} $${log-status} $${type} $${tcp-flags} $${pkt-srcaddr} $${pkt-dstaddr} $${pkt-src-aws-service} $${pkt-dst-aws-service} $${region} $${az-id} $${flow-direction} $${traffic-path}"

  tags = {
    Name = "${var.name}-flow-log"
  }
}
