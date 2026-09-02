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
- **Tiers went from 2 to 4**: `public`/`compute`/`data`/`transit`. `data` has zero internet route (not just an SG restriction) — mirrors `azure-virtual-network`'s `rt-data` design for consistency across both clouds. `transit` exists solely for a Transit Gateway VPC attachment.
- **NACLs**: 3, not 1-per-tier. `transit` NACL is deliberately wide open both directions — verified this is AWS's own explicit guidance (not a guess) via `search_documentation` on the TGW design best-practices guide before implementing it as permissive.
- **Every Interface endpoint has a real monthly cost** (~$22/month each for 3 AZs before data transfer) — each is independently opt-in (`enable_kms_endpoint`, `enable_ssm_endpoints`, `enable_secretsmanager_endpoint`, `enable_cloudwatch_logs_endpoint`, `enable_sts_endpoint`), all default `true`. Don't add more Interface endpoints without checking their per-AZ hourly cost first; Gateway endpoints (S3, DynamoDB) are free and shouldn't need the same scrutiny.
- **No CMK for the flow-logs log group**, on purpose — user explicitly corrected an earlier "let's add a CMK" direction to "always use AWS's managed keys, avoid unnecessary cost." Don't reintroduce a customer-managed KMS key here without that decision being revisited deliberately.

## Endpoints + VPC Encryption Controls round (2026-09-02, same day)

Added after the initial redesign, on request: DynamoDB Gateway endpoint, and 5 more Interface endpoints grouped as `local.interface_endpoints` + `for_each` in `endpoints.tf` (SSM/SSM Messages/EC2 Messages as one togglable trio since Session Manager needs all 3, plus Secrets Manager, CloudWatch Logs, STS) — 7 Interface endpoints total including KMS, sharing one security group (`aws_security_group.interface_endpoints`) instead of one per endpoint. Also added `aws_vpc_encryption_control` (`encryption_control.tf`) — a real AWS feature launched Nov 2025, verified via `get_provider_details` on the Terraform provider before use (not assumed from the blog post the user linked, which had no Terraform examples).

**Cost reality check, done via `search_documentation` before implementing**: the VPC Encryption Controls free introductory period (Nov 2025 – Feb 2026) had already ended by the time this was built (today is Sep 2026) — it's free only while the VPC is *empty* (no real resources), then a fixed hourly rate per VPC applies regardless of monitor/enforce mode. Defaulted to `mode = "monitor"` (pure audit, zero risk) rather than `enforce`, and pre-wired the `enforce`-only NAT/IGW exclusions so a future switch to enforce won't accidentally break internet egress.

**If enabling everything by default gets too expensive**: turning off all 7 Interface endpoints saves ~$154/month in hourly charges alone (before data processing) — see the README's cost summary table.

## Status

- 2026-09-02: Added DynamoDB Gateway endpoint + 5 more Interface endpoints + VPC Encryption Controls (monitor mode). Validated with a real `terraform plan` (63 resources, clean, not applied). `v0.2.0` tag is now behind these changes — needs a `v0.3.0` (or amend) before wiring into `jalcalaroot-aws-bootstrap/environments/dev`.
- 2026-09-02 (earlier): Full Well-Architected redesign (regional NAT, 4 tiers, 3 NACLs). 55 resources, clean plan. Tagged `v0.2.0`.
- 2026-09-02 (earlier still): Migrated from `jalcalaroot-aws-bootstrap`, tagged `v0.1.0`.
