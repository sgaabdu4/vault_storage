# Refresh Hard Eng package discovery

Status: Complete

## Outcome + scope

Install the latest verified Hard Eng package-discovery fix while preserving package APIs, dependencies, storage formats, version 5.0.1, and all existing verification requirements.

## Repository context

Owners: `.hooks/gate_config.py`, `.hooks/hard-eng-source.json`, and this plan. The existing Flutter workflow owns required CI; the version-tag publisher and package sources remain unchanged.

## Decisions + authorization

Blockers: None
Handoff: Approval
Authority: The user requested the latest Hard Eng throughout the active repositories and completion through origin/main. This tooling-only update adds no package publication or app distribution.

## Acceptance + steps

- [x] Install verified revision 2f9b4ec42702024faf72875128d3488b429ef4b9 through the supported upstream updater.
- [x] Confirm the package discovery file exactly matches upstream and existing project gates are unchanged.
- [x] Pass package and example analysis, tests, coverage, performance, dependency, security, and workflow checks.
- [x] Review the public diff; retain package publication contents and the existing version.

## Baseline + execution

Result: Passed
Evidence: The preceding scaffold update on main passed required CI and native delivered verification. Its root package coverage was 81.35% and example coverage 74.74%, above the unchanged 70% requirement. The new updater produced an isolated commit containing only two managed files; it did not run application checks.
Execution: One coordinator reviews the upstream diff, runs the existing native gate, then verifies the exact-head PR and main checks.

## Risks + recovery

The package-discovery change can affect developer check selection. The upstream fix retains real locked/workspace packages while excluding unowned lockfile-less test fixtures. Package runtime and stored data are unaffected; regressions can be repaired through a normal reviewed tooling commit.

## ux_reference

N/A — no package or example user interface changed.

## Verification

Result: Passed
Evidence: The full native Draft check passed with the updated scaffold: package and example lockfile, format, strict analysis, tests and line coverage, browser-download behavior, Dart Decimate, dependency boundaries, both performance budgets, secret scans, Actionlint, Zizmor, Shellcheck, OSV and Semgrep. Installed discovery code exactly matches the verified upstream revision and project gates are byte-identical.
E2E: N/A — no runtime behavior changed; existing package, browser-download and example behavior tests remain required in the native gate.

Delivery target: Merge
Delivery: Pending — verify the scoped branch, required checks at its exact head, merge, and verify main CI.
