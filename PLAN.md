# Update freezed to 4.0.3

Status: Complete

## Outcome + scope

Lock freezed at the latest stable 4.0.3 within the existing `^4.0.2` constraint; package APIs, storage formats, version 5.0.1 and other dependencies stay unchanged.

## Repository context

Owners: `pubspec.lock` (the freezed entry from the Dependabot update) and this plan. freezed is a dev dependency that generates code only; the example app does not use it. The Flutter workflow owns required CI; the version-tag publisher stays unchanged.
Same cause: N/A — a lock-only bump of one dev tool; the example lockfile does not list freezed and no earlier fix of this cause exists.

## Decisions + authorization

Blockers: None
Handoff: Approval
Authority: The user approved fixing and merging the open Dependabot updates. This dependency-only patch adds no package publication or app distribution.

## Acceptance + steps

- [x] The package lockfile resolves freezed 4.0.3 under `--enforce-lockfile`: N/A — a lock-only change; the native gate resolves and builds with the lockfile.
- [x] Package and example analysis, tests, coverage, dependency, security and workflow checks pass: N/A — no behavior changed; the native gate runs the existing tests.
- [x] The full PANA score holds: N/A — checked by the PANA job on the pull request.

## Baseline + execution

Result: Passed
Evidence: Dependabot CI on the update failed only because no applicable PLAN.md was changed; the Hard Eng check stopped before running package checks, and the format, analysis and test jobs only mirror that result. PANA passed on the same update.
Execution: One coordinator rebases the update, adds this plan, runs the native gate, then verifies the exact-head PR and main checks.

## Risks + recovery

freezed 4.0.3 is a patch release of a code generator used at build time only; it adds nothing to the published package at run time. Generated files are checked by the existing build and tests. Revert the lockfile entry to 4.0.2 if a regression appears.

## ux_reference

N/A — no package or example user interface changed.

## Verification

Result: Passed
Evidence: The native gate passed on the rebased branch: lockfile, format, strict analysis, tests and line coverage (package 81.35%, example 74.74%, minimum 70%), browser-download behavior, Dart Decimate, both performance budgets, secret scans, Actionlint, Zizmor, Shellcheck, OSV and Semgrep. The PANA job passed on the pull request. PANA was not run locally. An adversarial review approved the diff with no findings.
E2E: N/A — no package API or user flow changed; existing package, browser-download and example behavior tests remain required in the native gate.

Delivery target: Merge
Delivery: Pending — verify the scoped branch, required checks at its exact head, merge, and verify main CI.
