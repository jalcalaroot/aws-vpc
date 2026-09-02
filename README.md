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
  source = "git::https://github.com/jalcalaroot/aws-vpc.git?ref=v0.3.0"

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

### VPC Endpoints: 2 free Gateway, 7 real-cost Interface

Keeps AWS API traffic on the AWS backbone instead of routing through the NAT Gateway or the public internet — reduces both NAT data-processing cost and public attack surface. Every one of these is individually togglable — see `variables.tf`.

**Gateway (free — no hourly charge, no per-GB charge):**

| Endpoint | Variable | Associated with |
|---|---|---|
| S3 | `enable_s3_endpoint` (default `true`) | `compute` + `data` route tables |
| DynamoDB | `enable_dynamodb_endpoint` (default `true`) | `compute` + `data` route tables |

**Interface (real recurring cost — ~$0.01/hour *per AZ* + $0.01/GB processed. With 3 AZs, each one is roughly $22/month before any data transfer):**

| Endpoint(s) | Variable | Why |
|---|---|---|
| KMS | `enable_kms_endpoint` | Encryption operations (EBS, Secrets Manager, etc.) |
| SSM + SSM Messages + EC2 Messages (all 3 together) | `enable_ssm_endpoints` | Enables **Session Manager** — access EC2 instances in private subnets without a bastion host or exposed SSH. All 3 are required together for Session Manager to work; toggling this one variable controls all 3. |
| Secrets Manager | `enable_secretsmanager_endpoint` | App/DB credential retrieval |
| CloudWatch Logs | `enable_cloudwatch_logs_endpoint` | App logging (the VPC Flow Logs in this module do *not* need this — they're published by the AWS platform itself, not from an instance inside the VPC) |
| STS | `enable_sts_endpoint` | `sts:AssumeRole` from inside the VPC |

**All default to `false` — opt-in only.** Turning on every Interface endpoint costs roughly $154/month in hourly charges alone (7 endpoints × ~$22), before any data processing, so nothing here turns on by itself; enable each one explicitly at deployment time once a real workload actually needs it. One shared security group (`aws_security_group.interface_endpoints`) handles all of them; they all live in the `compute` subnets (Interface endpoints are reachable VPC-wide, not just from the subnet the ENI lives in, so `data` doesn't need its own ENIs too).

### VPC Encryption Controls

[AWS VPC Encryption Controls](https://aws.amazon.com/blogs/aws/introducing-vpc-encryption-controls-enforce-encryption-in-transit-within-and-across-vpcs-in-a-region/) (launched Nov 2025) audits (`monitor`) or enforces (`enforce`) encryption in transit for traffic within and across VPCs in the Region — the AWS equivalent of what [`azure-virtual-network`](https://github.com/jalcalaroot/azure-virtual-network) covers with Azure VNet encryption.

- Controlled by `enable_encryption_control` (**default `false` — opt-in**) and `encryption_control_mode` (default `"monitor"` — audits only, zero risk of blocking traffic, for whenever it's turned on).
- **Cost**: free while the VPC is *empty* (no real resources deployed). Once something real is running in it, **$0.15/hour per VPC in us-east-1** (~$110/month; up to $0.31/hour in some other regions — [see pricing announcement](https://aws.amazon.com/about-aws/whats-new/2026/03/vpc-encryption-controls-pricing/)), regardless of monitor/enforce mode. The free introductory period (Nov 2025 – Feb 2026) has already ended — that real number is why this defaults off.
- If you ever switch `encryption_control_mode` to `"enforce"`, this module automatically excludes NAT Gateway and Internet Gateway traffic from enforcement — traffic leaving to the public internet can't be encrypted by this AWS-backbone-only mechanism, so enforcing on it would just break egress.

### Flow logs: CloudWatch, AWS-managed encryption

Flow logs go to CloudWatch Logs (not S3) for real-time querying via Logs Insights. The log group uses the AWS-managed key (`aws/logs`, free) rather than a customer-managed KMS key — a CMK would add ~$1/month + per-request cost for a learning account with no compliance requirement forcing it; already documented inline with a `#checkov:skip`. Revisit if this ever needs to satisfy a real compliance requirement.

## Well-Architected review that drove this redesign

Reviewed against the [AWS Well-Architected Framework](https://docs.aws.amazon.com/wellarchitected/latest/framework/welcome.html) security pillar guidance (fetched live via docs search, not from memory). Findings addressed here:

- ✅ No NACLs at all before this redesign (default allow-all NACL only) — now has purpose-built NACLs per tier group.
- ✅ No VPC Endpoints — traffic to AWS services went through the NAT Gateway or public internet — now has 9 endpoints covering the most commonly needed AWS services.
- ✅ No encryption-in-transit story — now has VPC Encryption Controls in `monitor` mode.
- Already compliant before this redesign: default security group locked down (CIS AWS Benchmark), VPC Flow Logs enabled, no auto-assigned public IPs on private-tier subnets.

## Cost summary

| Item | Default | Approx. monthly cost |
|---|---|---|
| Regional NAT Gateway | always on (no toggle) | ~$32 base + data processing |
| 2 Gateway VPC Endpoints (S3, DynamoDB) | on | $0 |
| 7 Interface VPC Endpoints (KMS, SSM×3, Secrets Manager, CloudWatch Logs, STS) | **off** | ~$22 each if enabled (~$154 for all 7), before data processing |
| VPC Encryption Controls | **off** | $0 while empty; **~$0.15/hour (~$110/month) in us-east-1** once real resources are deployed, regardless of mode |
| Flow logs (CloudWatch, AWS-managed key) | on (no toggle) | Storage/ingestion only, no encryption surcharge |

Everything with a real recurring cost defaults to **off** — the only things a fresh `terraform apply` of this module creates that aren't free are the NAT Gateway and flow-log storage. Turn on Interface endpoints and Encryption Controls explicitly, per-project, once there's an actual workload that needs them.

## Status

- 2026-09-02: Added DynamoDB Gateway endpoint, 5 more Interface endpoints (SSM/SSM Messages/EC2 Messages, Secrets Manager, CloudWatch Logs, STS — 7 Interface endpoints total with KMS), and VPC Encryption Controls in `monitor` mode. Validated end-to-end with a real `terraform plan` (63 resources, clean) — not applied.
- 2026-09-02 (earlier): Full redesign — 3 AZs, 4 tiers (public/compute/data/transit), regional NAT Gateway, 3 NACLs. 55 resources, clean plan.
- 2026-09-02 (earlier still): Migrated from `jalcalaroot-aws-bootstrap/terraform/modules/vpc`, tagged `v0.1.0`.

See `CLAUDE.md` for conventions and session history.
