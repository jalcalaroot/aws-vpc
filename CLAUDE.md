# aws-vpc

Terraform module (not a deployable project) for the AWS network layer of the `jalcalaroot` account. Lives at the repo root — no `terraform/bootstrap`/`environments` split, that's for `jalcalaroot-aws-bootstrap`, which consumes this module.

## Conventions

- No state, no backend, no `provider` block here — a module never configures its own provider; the consumer's provider (with its own account, auth, `default_tags`) applies.
- No `tags` variable — let the consumer's `default_tags` (see `jalcalaroot-aws-bootstrap/terraform/modules/tags`) apply automatically, same as everywhere else in that account. Resource-level `Name` tags stay explicit (they're per-resource identifiers, not account-wide values); `default_tags` merges with them, doesn't replace them.
- Provider version constraint is intentionally loose (`>= 6.0`, no upper bound) — the consumer's own `~> 6.0` pin governs the actual resolved version. Don't tighten this to `~>` here.
- Version via git tags (`v0.1.0`, ...), consumers pin `?ref=<tag>` in their `source`. Never expect a consumer to track `main`.
- `examples/basic/` is how this module gets validated (`terraform validate`/`plan` needs a caller — a bare module has nothing to plan on its own).

## Relationship to `jalcalaroot-aws-bootstrap/terraform/modules/vpc`

That module already exists and works there (used for a real dev deployment, since torn down to avoid NAT Gateway cost — see that repo's CLAUDE.md). This repo replaces it as an external, versioned module. One fix made during the migration: the flow-logs CloudWatch log group name was hardcoded `/jalcalaroot/${var.name}/vpc-flow-logs` — the account-specific `jalcalaroot` segment was dropped (now `/${var.name}/vpc-flow-logs`) so this module isn't tied to one account's branding.

Once tagged, `jalcalaroot-aws-bootstrap/environments/dev` should point its VPC module source here instead of the local path, and the in-repo copy can be removed.

## Well-Architected redesign (2026-09-02, `v0.1.0` → `v0.2.0`)

Reviewed the `v0.1.0` module against the AWS Well-Architected Framework security pillar (fetched live via the AWS MCP docs search, not from memory) and rebuilt it. Full rationale is in the README — key points to remember here:

- **Regional NAT Gateway** (`nat.tf`) replaced the old single zonal NAT Gateway. This is a real AWS feature launched Nov 2025 (`aws_nat_gateway` with `availability_mode = "regional"`) — verified via `get_provider_details` on the Terraform provider docs before writing any code, not assumed. Needs AWS provider `>= 6.x` (recent point release — validated with 6.62.0). No `subnet_id`/`allocation_id` on this resource; it attaches to the VPC directly and auto-manages EIPs/AZ coverage.
- **Billing gotcha, caught during a README accuracy audit (2026-09-02)**: a regional NAT Gateway is billed **per Availability Zone it actively serves**, not as one flat "NAT Gateway-hour" — AWS's own pricing page: "you are charged for each hour that the NAT Gateway is configured in each availability zone... if your regional NAT is running across three AZs for one hour, you'll be billed for three NAT Gateway-hours." At `$0.045/hr/AZ` (us-east-1) and the default `az_count = 3`, that's **~$98/month base**, not ~$32/month as the README previously (incorrectly) stated — a 3x understatement of what's actually accruing right now on the live `jalcalaroot-dev` VPC. Don't quote a flat per-NAT-Gateway price for this resource again; always multiply by the AZ count it's actually covering.
- **Tiers went from 2 to 4**: `public`/`compute`/`data`/`transit`. `data` has zero internet route (not just an SG restriction) — mirrors `azure-virtual-network`'s `rt-data` design for consistency across both clouds. `transit` exists solely for a Transit Gateway VPC attachment.
- **NACLs**: 3, not 1-per-tier. `transit` NACL is deliberately wide open both directions — verified this is AWS's own explicit guidance (not a guess) via `search_documentation` on the TGW design best-practices guide before implementing it as permissive.
- **Every Interface endpoint has a real monthly cost** (~$22/month each for 3 AZs before data transfer) — each is independently toggleable (`enable_kms_endpoint`, `enable_ssm_endpoints`, `enable_secretsmanager_endpoint`, `enable_cloudwatch_logs_endpoint`, `enable_sts_endpoint`), **all default `false`** (changed from an initial `true` default after pricing this out for real — see below). Don't add more Interface endpoints without checking their per-AZ hourly cost first; Gateway endpoints (S3, DynamoDB) are free, default `true`, and shouldn't need the same scrutiny.
- **No CMK for the flow-logs log group**, on purpose — user explicitly corrected an earlier "let's add a CMK" direction to "always use AWS's managed keys, avoid unnecessary cost." Don't reintroduce a customer-managed KMS key here without that decision being revisited deliberately.

## Endpoints + VPC Encryption Controls round (2026-09-02, same day)

Added after the initial redesign, on request: DynamoDB Gateway endpoint, and 5 more Interface endpoints grouped as `local.interface_endpoints` + `for_each` in `endpoints.tf` (SSM/SSM Messages/EC2 Messages as one togglable trio since Session Manager needs all 3, plus Secrets Manager, CloudWatch Logs, STS) — 7 Interface endpoints total including KMS, sharing one security group (`aws_security_group.interface_endpoints`) instead of one per endpoint. Also added `aws_vpc_encryption_control` (`encryption_control.tf`) — a real AWS feature launched Nov 2025, verified via `get_provider_details` on the Terraform provider before use (not assumed from the blog post the user linked, which had no Terraform examples).

**Cost reality check, done via `search_documentation` before implementing**: the VPC Encryption Controls free introductory period (Nov 2025 – Feb 2026) had already ended by the time this was built (today is Sep 2026) — it's free only while the VPC is *empty* (no real resources), then a fixed hourly rate per VPC applies regardless of monitor/enforce mode. Defaulted to `mode = "monitor"` (pure audit, zero risk) rather than `enforce`, and pre-wired the `enforce`-only NAT/IGW exclusions so a future switch to enforce won't accidentally break internet egress.

**Initial default was `enable_encryption_control = true` and all Interface endpoints `true`** — changed to `false` (opt-in) across the board once the *exact* price was looked up: **$0.15/hour per VPC in us-east-1 (~$110/month)** once the VPC has any real resource in it, regardless of mode. That single line item alone would have cost more than all 7 Interface endpoints combined (~$154/month). User's own words when correcting this: "quitarlo y los endpoints también, solo deja los gratuitos, y los de costos opcionales al momento del despliegue" — this repo's baseline philosophy now: **nothing with a real recurring cost is on by default**, not even something as security-valuable as encryption-in-transit auditing. Don't flip any `enable_*` cost variable back to `true` by default without that being a deliberate, explicit decision.

## DevSecOps CI hardening (2026-09-02, `v0.4.0` → `v0.5.0`)

Workspace-wide audit found this repo's CI running only `fmt`+`validate` — the weakest gate of any repo despite defining the actual deployed resources. Added `tflint` (aws ruleset) + Checkov (blocking) to `terraform-validate.yml`, plus a standalone `gitleaks` workflow. Also enabled GitHub branch protection on `main` (free — this is a public repo) requiring both `fmt + validate` and `gitleaks` to pass; direct pushes to `main` are no longer possible even locally.

Found and fixed one real issue while getting Checkov clean: `aws_security_group.interface_endpoints`'s egress was `0.0.0.0/0` on all ports with no rule description — scoped to `var.vpc_cidr` on 443 instead (endpoint ENIs only ever respond within the VPC, never initiate outbound traffic). No functional impact on the deployed `jalcalaroot-dev` VPC — interface endpoints are all off by default there.

12 Checkov exceptions on the NACLs, all pre-existing intentional design (documented inline with `#checkov:skip`): transit NACL wide-open per AWS's own TGW guidance, shared private NACL by design, ephemeral port ranges (1024-65535) false-flagged against well-known ports like 3389, and `subnet_ids` set via splat (`aws_subnet.x[*].id`) not resolved by Checkov's graph analysis (`CKV2_AWS_1` false positive — verify the real association with `aws ec2 describe-network-acls` if ever in doubt).

## Status

- 2026-09-02: DevSecOps hardening - tflint+Checkov+gitleaks in CI, branch protection on `main`, interface-endpoint SG egress tightened. Tagged `v0.5.0`.
- 2026-09-02: Flipped every cost-incurring `enable_*` variable to default `false` (Interface endpoints, encryption control) after pricing out VPC Encryption Controls exactly (~$110/month, not just "a fixed hourly rate"). Only the free Gateway endpoints (S3, DynamoDB) default `true`. Re-validated (55 resources by default now, matching the pre-endpoint-expansion count).
- 2026-09-02 (earlier, same day): Added DynamoDB Gateway endpoint + 5 more Interface endpoints + VPC Encryption Controls, all defaulting `true` at the time. Validated with a real `terraform plan` (63 resources, clean, not applied). Tagged `v0.3.0` — that tag predates the default flip above, so `v0.3.0`'s defaults are more expensive than what's currently on `main`. Not yet re-tagged or wired into `jalcalaroot-aws-bootstrap/environments/dev`.
- 2026-09-02 (earlier still): Full Well-Architected redesign (regional NAT, 4 tiers, 3 NACLs). 55 resources, clean plan. Tagged `v0.2.0`.
- 2026-09-02 (earliest): Migrated from `jalcalaroot-aws-bootstrap`, tagged `v0.1.0`.
