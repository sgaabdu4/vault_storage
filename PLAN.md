# Update freerasp to 8.2.4

Status: Complete

## Outcome + scope

Lock freerasp at the latest stable 8.2.4 within the existing `^8.2.2` constraint; package APIs, storage formats, version 5.0.1 and other dependencies stay unchanged.

## Repository context

Owners: `pubspec.lock` (the freerasp entry from the Dependabot update), the same entry in `example/pubspec.lock`, and this plan. freerasp is used by `lib/src/vault_storage_impl.dart`, `lib/src/vault_storage_impl_helpers.dart` and `lib/src/mock/freerasp_mock.dart`. The Flutter workflow owns required CI; the version-tag publisher stays unchanged.

## Decisions + authorization

Blockers: None
Handoff: Approval
Authority: The user approved fixing and merging the open Dependabot updates. This dependency-only patch adds no package publication or app distribution.

## Acceptance + steps

- [x] Rebase the Dependabot update onto current main; both package and example lockfiles resolve freerasp 8.2.4 under `--enforce-lockfile`.
- [x] Pass package and example analysis, tests, coverage, performance, dependency, security and workflow checks in the native gate.
- [x] Pass the full PANA score, including WASM compatibility.
- [x] Review the public diff; keep package publication contents and the existing version.

## Baseline + execution

Result: Passed
Evidence: Dependabot CI on the update failed only because no applicable PLAN.md was changed; the Hard Eng check stopped before running package checks, and the format, analysis and test jobs only mirror that result. PANA passed with the full score on the same update.
Execution: One coordinator rebases the update, adds this plan, runs the native gate, then verifies the exact-head PR and main checks.

## Risks + recovery

freerasp 8.2.4 is a patch release of the threat-detection plugin; a behavior change could affect security callbacks. The existing package tests cover the freerasp integration through its mock, and CI runs them. Revert both lockfile entries to 8.2.2 if a regression appears.

## ux_reference

N/A — no package or example user interface changed.

## Verification

Result: Passed
Evidence: The native gate passed on the rebased branch: package and example lockfile, format, strict analysis, tests and line coverage (package 81.35%, example 74.74%, minimum 70%), browser-download behavior, Dart Decimate, both performance budgets, secret scans, Actionlint, Zizmor, Shellcheck, OSV and Semgrep. PANA 0.23.19 scored 160/160, including WASM compatibility. An adversarial review approved the diff with no findings.
E2E: N/A — no package API or user flow changed; existing package, browser-download and example behavior tests remain required in the native gate.

Delivery target: Merge
Delivery: Pending — verify the scoped branch, required checks at its exact head, merge, and verify main CI.
