# aws-vpc

Terraform module (not a deployable project) for the AWS network layer of the `jalcalaroot` account. Lives at the repo root — no `terraform/bootstrap`/`environments` split, that's for `jalcalaroot-aws`, which will consume this module.

## Conventions

- No state, no backend, no `provider` block here — a module never configures its own provider; the consumer's provider (with its own account, auth, `default_tags`) applies.
- Don't set tags explicitly per resource — let the consumer's `default_tags` (see `jalcalaroot-aws/terraform/modules/tags`) apply automatically, same as everywhere else in that account.
- Version via git tags (`v0.1.0`, ...), consumers pin `?ref=<tag>` in their `source`. Never expect a consumer to track `main`.
- `examples/` (once it exists) is how this module gets validated in CI — `terraform validate`/`plan` needs a caller, a bare module has nothing to plan.

## Relationship to `jalcalaroot-aws/terraform/modules/vpc`

That module already exists and works (used it for the dev VPC, now torn down — see `jalcalaroot-aws/CLAUDE.md`). This repo is meant to replace it as an external, versioned module rather than an in-repo one. Migrate the code here, don't rewrite from scratch, and update `jalcalaroot-aws/environments/dev` to source from here once this repo has a tagged release.

## Status

- 2026-09-02: Repo created. No module code yet.
