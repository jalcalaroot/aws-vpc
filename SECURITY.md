# Security Policy

This is a personal learning/reference Terraform module (AWS), not intended for production use as-is. There are no supported version branches — only `main` is maintained; consumers should pin a tagged release.

## Reporting a Vulnerability

If you find a security issue — a misconfigured resource default, an overly permissive security group rule, a leaked credential in git history — please report it privately using [GitHub's private vulnerability reporting](../../security/advisories/new) instead of opening a public issue.

## Scope

- This module's Terraform configuration and the AWS resources it defines

Out of scope: vulnerabilities in the underlying Terraform providers or AWS services — please report those to their respective maintainers.
