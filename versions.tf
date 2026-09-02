terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0" # piso alineado con jalcalaroot-aws-bootstrap (~> 6.0) - sin límite superior a propósito, así el consumidor decide la versión exacta
    }
  }
}
