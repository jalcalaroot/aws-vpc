# Minimal example, exercised in CI via `terraform validate` (no apply - a
# bare module has nothing to plan without a caller like this one).

terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = "jalcalaroot"
      Environment = "dev"
      Owner       = "johan"
      ManagedBy   = "terraform"
      resource    = "jalcalaroot"
    }
  }
}

module "vpc" {
  source = "../.."

  name     = "jalcalaroot-dev"
  vpc_cidr = "10.0.0.0/16"
  # az_count no se pasa - usa el default del módulo (3 AZs)
}
