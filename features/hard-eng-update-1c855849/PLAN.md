# Hard Eng 1c855849 update

Status: Complete

## Outcome + scope

The repo runs Hard Eng `1c855849` installed by the supported updater, with every repository check passing. Out of scope: package code and version, dependency updates, publish workflow, and the performance budgets.

## Repository context

Owners: `.hooks/hard-eng-source.json` and the updater commit (installed revision); `.hooks/`, `.agents/skills/` and the Hard Eng block of `AGENTS.md` (scaffold); `.github/workflows/flutter.yml` (the Hard Eng CI job). The updater reported `CI adaptation pending`: the job ran the check without Bun, so the Node and pnpm setup steps become one `oven-sh/setup-bun` step.

## Decisions + authorization

Blockers: None
Handoff: Approval
Authority: Agent-loop under the owner's Hard Eng update request: update to `1c855849`, fix what the update reports at its owner, merge when CI is green.

## Acceptance + steps

- [x] Installed revision is `1c855849` -> `.hooks/hard-eng-source.json` shows `1c855849c99b3c3dc3a4fa3fab1f20d0ce0b3911` after `python3 .hooks/hard-eng.py update`.
- [x] CI job sets up Bun -> `.github/workflows/flutter.yml` has the template's pinned `oven-sh/setup-bun` step and no Node or pnpm step; the CI check job passes.
- [x] Repository checks pass on the updated scaffold -> `python3 .hooks/hard-eng.py check` exits 0.

## Baseline + execution

Result: Passed
Evidence: Starting revision `5c4643d` (Hard Eng `02f02959`). The first `python3 .hooks/hard-eng.py check` run after the update only reported the missing plan; the CI adaptation notice named the missing Bun step.
Execution: Single builder; scaffold update plus one workflow edit.

## Risks + recovery

The CI job runs on a changed toolchain (Bun replaces Node and pnpm). Recovery = revert the PR.

## ux_reference

N/A — tooling only; no rendered interface changes.

## Verification

Result: Passed
Evidence: Full `python3 .hooks/hard-eng.py check` without a base passed (20 checks passed, 0 failed across the package, the example and the shared checks; `secure-stream-performance` 4.2 s against its 5 s budget; line coverage 81.35% package, 74.74% example, minimum 70%).
E2E: N/A — no user journey changes; the native package and example tests cover the library.

Delivery target: Merge
Delivery: Pending — PR merged into main with every required check passing on the merged revision.
