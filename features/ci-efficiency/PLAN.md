# Vault CI and native agent migration

Status: Complete

## Outcome + scope

Remove repeated dependency resolution and analyzer/scanner work while updating the released Claude/Codex scaffold. Preserve protected checks, browser coverage, performance, versioning and pub.dev publishing. Product behavior and SDK choices remain unchanged.

## Repository context

Owners: `.github/workflows/flutter.yml`, `hard-eng.gates.json`, `AGENTS.md`, native Claude/Codex settings and the supported Hard Eng updater.

## Decisions + authorization

Blockers: None
Handoff: Approval
Authority: Autonomous — the user authorized released-source migration, pnpm wherever supported, Claude/Codex-only tooling, one combined pull request per repository, review, checks and merge.

## Acceptance + steps

- [x] Released scaffold at `1a1f86094fb7ceb36fd7abb7a400d056354bc1f8` → supported updater succeeds; repeat changes nothing; repository CLAUDE aliases and retired tooling are absent while unique guidance remains.
- [x] Root and example resolve locked dependencies once in the Hard Eng owner; protected status names and full PANA scoring remain. → native gates and workflow checks pass with the original assertions.
- [x] Browser coverage and both performance workloads retain their existing thresholds. → existing native tests and configured checks pass.
- [x] Actual verification and runner timing → retain measured commands/results; make no unsupported percentage claim.

## Baseline + execution

Result: Passed
Evidence: Starting `904d49ecfb16cc7dfd8be8300cbcd88b96a8ce20` completed [native CI](https://github.com/sgaabdu4/vault_storage/actions/runs/35975091217) successfully before migration; local released-updater candidate verification also passed; see Verification.
Execution: One builder at existing owners, followed by diff review and the native candidate, Ready and shipping checks. Heavy suites run only in the coordinated slot.

## Risks + recovery

Preserve custom settings and instruction tails before retirement. Stop on a conflicting updater plan; recover a known migration change through Git without overwriting unrelated work. Retain existing publishing and product safety guards.

## ux_reference

N/A — agent configuration and CI only; no app interface or appearance changes.

## Verification

Result: Passed
Evidence: Released setup.sh/native updater completed at 1a1f86094fb7ceb36fd7abb7a400d056354bc1f8; all 21 candidate checks passed, including browser coverage (7.607s), root tests (24.280s), example tests (8.083s) and performance workloads (2.415s / 1.239s). The retained whole-package fatal-info analyzer also passed; the narrower repeated analyzer was then removed. Both package scanners are now one unfiltered strict invocation each. Workflow actionlint passed. Independent review of the project-specific diff found no defects. The repeat updater exited 0 with no changed files or duplicate commit. Existing primary Codex Dart/Marionette settings are preserved after removing only retired servers; the Dart root fallback option remains valid under native MCP help. Starting hosted Hard Eng check measured 186s; new hosted timing remains delivery proof.
E2E: N/A — no product journey changes; supported updater behavior and actual hosted workflow results are the relevant proof.

Delivery target: Merge
Delivery: Pending — exact pull request checks, guarded merge and merged-main results remain required.
