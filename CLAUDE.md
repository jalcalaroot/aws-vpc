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

## Status

- 2026-09-02: Migrated from `jalcalaroot-aws-bootstrap`. Validated end-to-end with a real `terraform plan` against the `jalcalaroot` AWS account (19 resources, clean, not applied). Not tagged/released yet.
