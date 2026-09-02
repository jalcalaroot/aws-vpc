# aws-vpc

Reusable Terraform module for the AWS network layer used by the `jalcalaroot` account's projects. Redesigned 2026-09-02 after a security review against the AWS Well-Architected Framework — see [Design decisions](#design-decisions) for what changed and why.

## Architecture

4 tiers × 3 Availability Zones = 12 subnets:

| Tier | Purpose | Internet egress | NACL |
|---|---|---|---|
| `public` | ALBs, bastion, anything with a direct public IP | Direct via Internet Gateway | `public` — only 80/443 in, ephemeral return traffic |
| `compute` | App servers, containers — the actual workload | Via the regional NAT Gateway | `private` (shared with `data`) |
| `data` | Databases, storage — no internet at all | **None** — no `0.0.0.0/0` route in the route table, at all | `private` (shared with `compute`) |
| `transit` | Transit Gateway VPC attachment only, nothing else runs here | N/A | `transit` — open both directions (AWS's own explicit recommendation for TGW attachment subnets) |

## Usage

```hcl
module "vpc" {
  source = "git::https://github.com/jalcalaroot/aws-vpc.git?ref=v0.2.0"

  name     = "jalcalaroot-dev"
  vpc_cidr = "10.0.0.0/16"
  az_count = 3 # default
}
```

No `tags` variable — relies on the caller's provider `default_tags`, same as the rest of the `jalcalaroot-aws-bootstrap` account. See `variables.tf`/`outputs.tf` for the full interface. `examples/basic/` is the minimal caller used to validate the module in CI.

## Design decisions

### Regional NAT Gateway, not one-per-AZ

AWS shipped [regional NAT gateways](https://aws.amazon.com/blogs/networking-and-content-delivery/introducing-amazon-vpc-regional-nat-gateway/) in November 2025 — a single `aws_nat_gateway` resource with `availability_mode = "regional"` that auto-expands across every AZ where the VPC has subnets, instead of the old pattern of one zonal NAT Gateway per AZ (each needing its own EIP, public subnet, and per-AZ route table wiring). One resource, full multi-AZ redundancy, no single point of failure — replaces what used to be a documented trade-off in this module (single shared zonal NAT Gateway, AZ failure = private subnets in that AZ lose egress). Requires a `>= 6.x` AWS provider (validated with 6.62.0).

### Four tiers instead of two (`public`/`private`)

`data` is now split out from `compute` with its own subnets and **zero internet route** — not just a security group restriction, an actual routing-level block, same defense-in-depth principle as the `data` tier in the sibling [`azure-virtual-network`](https://github.com/jalcalaroot/azure-virtual-network) module (`rt-data` there blocks `0.0.0.0/0` the same way). `transit` is a dedicated tier for a Transit Gateway VPC attachment — nothing else is meant to run there.

### Network ACLs: 3, not per-tier

Two workload NACLs (`public`, and one `private` NACL shared by `compute`+`data`) plus a dedicated `transit` NACL. The workload NACLs mirror what a reasonable security-group setup would already allow (broad intra-VPC + necessary ports) — NACLs here are a second layer, not the primary enforcement; that stays with each consumer's own security groups. `transit` is a separate NACL and it's **wide open in both directions** — that's not an oversight, it's [AWS's own explicit Transit Gateway design guidance](https://docs.aws.amazon.com/vpc/latest/tgw/tgw-best-design-practices.html): a restrictive NACL on TGW attachment subnets can interfere with TGW routing.

### Transit subnets are `/28`, not `/24`

Per the same AWS Transit Gateway best-practice guide: a TGW attachment subnet only ever hosts the attachment's single ENI, so a `/28` (16 addresses) is the recommended size — no reason to burn a `/24` on it. Carved from a separate `/24` block (`cidrsubnet(vpc_cidr, 8, 250)`) so it doesn't compete for address space with the three `/24`-per-AZ workload tiers.

### VPC Endpoints: S3 (free) and KMS (real cost, opt-in)

Keeps AWS API traffic on the AWS backbone instead of routing through the NAT Gateway or the public internet — reduces both NAT data-processing cost and public attack surface.

- **S3** (`enable_s3_endpoint`, default `true`): Gateway endpoint, genuinely free (no hourly charge, no per-GB charge), associated with the `compute` and `data` route tables.
- **KMS** (`enable_kms_endpoint`, default `true`): Interface endpoint — **has a real recurring cost**, ~$0.01/hour per AZ + $0.01/GB processed. With 3 AZs that's roughly **$22/month before any data transfer**. One ENI per AZ, placed in the `compute` subnets only (Interface endpoints are reachable VPC-wide, not just from the subnet the ENI lives in, so `data` doesn't need its own ENIs too). Toggle it off if nothing in the VPC is calling the KMS API often enough to justify the cost.

### Flow logs: CloudWatch, AWS-managed encryption

Flow logs go to CloudWatch Logs (not S3) for real-time querying via Logs Insights. The log group uses the AWS-managed key (`aws/logs`, free) rather than a customer-managed KMS key — a CMK would add ~$1/month + per-request cost for a learning account with no compliance requirement forcing it; already documented inline with a `#checkov:skip`. Revisit if this ever needs to satisfy a real compliance requirement.

## Well-Architected review that drove this redesign

Reviewed against the [AWS Well-Architected Framework](https://docs.aws.amazon.com/wellarchitected/latest/framework/welcome.html) security pillar guidance (fetched live via docs search, not from memory). Findings addressed here:

- ✅ No NACLs at all before this redesign (default allow-all NACL only) — now has purpose-built NACLs per tier group.
- ✅ No VPC Endpoints — traffic to AWS services went through the NAT Gateway or public internet — now has S3 (free) and KMS (opt-in) endpoints.
- Already compliant before this redesign: default security group locked down (CIS AWS Benchmark), VPC Flow Logs enabled, no auto-assigned public IPs on private-tier subnets.

## Status

- 2026-09-02: Full redesign — 3 AZs, 4 tiers (public/compute/data/transit), regional NAT Gateway, 3 NACLs, S3 + KMS VPC endpoints. Validated end-to-end with a real `terraform plan` against the `jalcalaroot` AWS account (55 resources, clean) — not applied.
- 2026-09-02 (earlier): Migrated from `jalcalaroot-aws-bootstrap/terraform/modules/vpc`, tagged `v0.1.0`.

See `CLAUDE.md` for conventions and session history.
