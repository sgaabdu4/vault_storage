# Bump hive_ce from 2.20.1 to 2.22.0

Status: Complete

## Outcome + scope

The package resolves `hive_ce` 2.22.0 instead of 2.20.1, with every repository check passing. Out of scope: other dependencies, package code and version, and the publish workflow.

## Repository context

Owners: `pubspec.lock` (dependency constraint and lock). Dependabot opened PR #52 with the bump; this plan records it for the Hard Eng plan gate.

## Decisions + authorization

Blockers: None
Handoff: Approval
Authority: The owner asked on 2026-10-22 to merge all open PRs that can go green.

## Acceptance + steps

- [x] `hive_ce` resolves to 2.22.0 -> `pubspec.lock` on this branch.
- [x] Repository checks pass with the new version -> the PR's Hard Eng CI check runs `python3 .hooks/hard-eng.py check` with every toolchain.

## Baseline + execution

Result: Passed
Evidence: Before this plan, the PR's only failing gate was "repository changes need an applicable PLAN.md".
Execution: Dependabot change plus this plan.

## Risks + recovery

A minor or patch release can change behaviour. Recovery = revert the PR.

## ux_reference

N/A — dependency update only; no rendered interface changes.

## Verification

Result: Passed
Evidence: PR CI runs the full `python3 .hooks/hard-eng.py check` on this branch, including tests and coverage.
E2E: N/A — no user journey changes; the package tests cover the library.

Delivery target: Merge
Delivery: Pending — PR merged into main with every required check passing.
