# aws-vpc

Reusable Terraform module for the AWS network layer (VPC, public/private subnets per AZ, IGW, single NAT Gateway, VPC Flow Logs) used by the `jalcalaroot` account's projects. Migrated from `jalcalaroot-aws-bootstrap/terraform/modules/vpc`'s proven design (used for a real dev deployment already).

## Stack

- **IaC**: Terraform module, consumed via `source = "git::https://github.com/jalcalaroot/aws-vpc.git?ref=<tag>"` — this repo has no backend or state of its own.
- **Consumer**: `jalcalaroot-aws-bootstrap` (and future projects in that account).

## Usage

```hcl
module "vpc" {
  source = "git::https://github.com/jalcalaroot/aws-vpc.git?ref=v0.1.0"

  name     = "jalcalaroot-dev"
  vpc_cidr = "10.0.0.0/16"
  az_count = 2
}
```

No `tags` variable — this module relies on the caller's provider `default_tags` to tag everything automatically (same as the rest of the `jalcalaroot-aws-bootstrap` account). See `variables.tf`/`outputs.tf` for the rest of the interface.

`examples/basic/` is a minimal caller used to validate the module in CI (`terraform validate` — a bare module has nothing to plan without a caller).

## Status

- 2026-09-02: Migrated from `jalcalaroot-aws-bootstrap/terraform/modules/vpc`. One fix made in the move: the flow-logs CloudWatch log group name was hardcoded to `/jalcalaroot/${var.name}/vpc-flow-logs` — dropped the account-specific `jalcalaroot` segment (now `/${var.name}/vpc-flow-logs`) so the module isn't tied to one account's branding. Validated end-to-end with a real `terraform plan` against the `jalcalaroot` AWS account (19 resources, clean) — not applied.

See `CLAUDE.md` for conventions.
