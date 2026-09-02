# aws-vpc

Reusable Terraform module for the AWS network layer (VPC, subnets, IGW, NAT Gateway) used by the `jalcalaroot` account's projects.

## Stack

- **IaC**: Terraform module, consumed via `source = "git::https://github.com/jalcalaroot/aws-vpc.git?ref=<tag>"` — this repo has no backend or state of its own.
- **Consumer**: `jalcalaroot-aws` (and future projects in that account).

## Usage

Not implemented yet — see Status below.

## Status

Early stage — repo scaffolding only, no module code yet. Design pending. Note: `jalcalaroot-aws/terraform/modules/vpc` already has a working VPC module inline in that repo — decide whether this repo replaces it or they diverge before writing code here.

See `CLAUDE.md` for conventions.
