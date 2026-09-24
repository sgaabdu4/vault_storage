# Refresh the installed Hard Eng scaffold

Status: Complete

## Outcome + scope

Update the repository tooling to the latest CI-verified Hard Eng revision and remove installer-owned skills no longer applicable to this package. Package APIs, dependencies, storage formats and the published version remain unchanged.

## Repository context

Owners: `.hooks/`, `.agents/skills/`, `.claude/skills/`, `hard-eng.gates.json`, and this plan. The existing Flutter workflow owns required CI; the version-tag publisher is unchanged. The previous storage refactor and version 5.0.1 release are recorded in repository history.

## Decisions + authorization

Blockers: None
Handoff: Approval
Authority: The user requested the latest Hard Eng installation throughout the active repositories, removal of obsolete tooling and completion through origin/main. No application distribution or new package version is part of this scaffold-only change.

## Acceptance + steps

- [x] Install the supported verified revision b5a5d31c67aba93e87f19ff058f3b012d99a9413 through the upstream setup command.
- [x] Remove only installer-owned unused Appwrite guidance; preserve package sources, existing coverage and performance checks.
- [x] Pass strict analysis, tests, coverage, formatting, boundaries, performance, dependency/security and workflow checks under the updated scaffold.
- [x] Review the complete public diff and keep package publication contents unchanged.

## Baseline + execution

Result: Passed
Evidence: The supported updater ran the existing repository gates before recording its isolated local scaffold commit. Root package line coverage was 798/981 (81.35%) and example coverage 213/285 (74.74%), both above the unchanged 70% requirement. Both performance budgets passed. The first delivery attempt correctly stopped because the previous release plan did not apply to this new scaffold change.
Execution: One coordinator reviewed the generated scaffold diff and updated this existing plan. The pre-push gate rechecks the actual outgoing commit, followed by exact-head GitHub checks before merge.

## Risks + recovery

Changes affect developer verification and setup only. The updater-owned revision and diff are recorded together; a regression can be repaired through a normal reviewed tooling change without modifying stored user data. Existing package runtime and publishing workflow are unchanged.

## ux_reference

N/A — only repository tooling and documentation changed; no application or example interface changed.

## Verification

Result: Passed
Evidence: The upstream setup command installed b5a5d31 and passed lockfile, formatting, strict analysis, package and example tests with coverage, browser-download coverage, Dart Decimate, dependency boundaries, both performance checks, actionlint, shellcheck, Zizmor, secret scans, vulnerability and security checks. The complete diff contains only installer-owned scaffold files, gate integration and this plan; all are excluded from package publication by the existing pubignore.
E2E: N/A — this change adds no runtime behavior or user interaction; the retained package, browser-download and example behavior tests passed under the new scaffold.

Delivery target: Merge
Delivery: Pending — push the scoped task branch, verify required checks for its exact head, merge and verify main CI.
