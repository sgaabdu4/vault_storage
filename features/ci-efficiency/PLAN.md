# Vault CI and native agent migration

Status: Draft

## Outcome + scope

Remove repeated dependency resolution and analyzer/scanner work while updating the released Claude/Codex scaffold. Preserve protected checks, browser coverage, performance, versioning and pub.dev publishing. Product behavior and SDK choices remain unchanged.

## Repository context

Owners: `.github/workflows/flutter.yml`, `hard-eng.gates.json`, `AGENTS.md`, native Claude/Codex settings and the supported Hard Eng updater.

## Decisions + authorization

Blockers: None
Handoff: Approval
Authority: Autonomous — the user authorized released-source migration, pnpm wherever supported, Claude/Codex-only tooling, one combined pull request per repository, review, checks and merge.

## Acceptance + steps

- [ ] Released scaffold at `1a1f86094fb7ceb36fd7abb7a400d056354bc1f8` → supported updater succeeds; repeat changes nothing; repository CLAUDE aliases and retired tooling are absent while unique guidance remains.
- [ ] Root and example resolve locked dependencies once in the Hard Eng owner; protected status names and full PANA scoring remain. → native gates and workflow checks pass with the original assertions.
- [ ] Browser coverage and both performance workloads retain their existing thresholds. → existing native tests and configured checks pass.
- [ ] Actual verification and runner timing → retain measured commands/results; make no unsupported percentage claim.

## Baseline + execution

Result: Passed
Evidence: Starting `904d49ecfb16cc7dfd8be8300cbcd88b96a8ce20` completed [native CI](https://github.com/sgaabdu4/vault_storage/actions/runs/35975091217) successfully before migration; local updater candidate verification is pending the shared test slot.
Execution: One builder at existing owners, followed by diff review and the native candidate, Ready and shipping checks. Heavy suites run only in the coordinated slot.

## Risks + recovery

Preserve custom settings and instruction tails before retirement. Stop on a conflicting updater plan; recover a known migration change through Git without overwriting unrelated work. Retain existing publishing and product safety guards.

## ux_reference

N/A — agent configuration and CI only; no app interface or appearance changes.

## Verification

Result: Pending
Evidence: Native candidate and final verification have not run yet.
E2E: N/A — no product journey changes; supported updater behavior and actual hosted workflow results are the relevant proof.

Delivery target: Merge
Delivery: Pending — exact pull request checks, guarded merge and merged-main results remain required.
