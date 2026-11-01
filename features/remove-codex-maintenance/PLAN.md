# Remove the scheduled Codex maintenance workflow

Status: Complete

## Outcome + scope

The repository no longer has the scheduled Codex maintenance workflow. Non-goals: other workflows, Dependabot configuration and the `maintenance` environment with its variables and secret.

## Repository context

Owners: `.github/workflows/codex-maintenance.yml` (self-contained: weekly cron, `maintenance` environment, Gmail variables and secret). Nothing else references it.
Same cause: N/A — not a defect; the owner removed the same workflow from every repository on 2026-10-31.

## Decisions + authorization

Blockers: None
Handoff: Approval
Authority: The owner asked on 2026-10-31 to remove Codex maintenance from every repository. The workflow was switched off the same day before this change.

## Acceptance + steps

- [x] The workflow file is gone and nothing references it → N/A — no repository test covers a deleted workflow; `git grep codex-maintenance` finds only plan files.

## Baseline + execution

Result: Passed
Evidence: `main` at `31fc9ec1db4194bcced9f76309d28c594d993420` passed CI before this change; the workflow was switched off with `gh workflow disable` before this change.
Execution: One change: delete the workflow.

## Risks + recovery

Risk: Dependabot pull requests no longer queue for merge automatically and no maintenance email is sent. Recovery: restore the file from git history.

## ux_reference

N/A — CI workflow removal with no visible surface.

## Verification

Result: Passed
Evidence: `git grep codex-maintenance` finds only plan files.
E2E: N/A — removing a scheduled workflow has no user journey; pull request CI and the default branch run cover delivery.

Delivery target: Merge
Delivery: Pending — pull request checks, then the default branch push run.
