terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0" # piso alineado con jalcalaroot-aws-bootstrap (~> 6.0), sin límite superior a propósito. El NAT Gateway regional (nat.tf) necesita un 6.x reciente - validado con 6.62.0 (ver .terraform.lock.hcl); si tu 6.x es viejo y falla en `availability_mode`, hacé `terraform init -upgrade`.
    }
  }
}
