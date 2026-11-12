# Update outdated packages, add the freshness check and repair old findings

Status: Complete

## Outcome + scope

Lock freerasp 8.3.0, hive_ce 2.23.3, web 1.1.2 and build_runner 2.17.1 (the latest stable releases), add the freshness check that the Hard Eng release requires, and repair the findings the full check reports: await-in-loop and sequential-await speed rules in `lib`, two regexes built inside functions in `tool`, and one workflow pin comment. The newest Hard Eng release then needs two more repairs: the browser coverage harness leaves `tool` for `test/browser` and the Flutter workflow runs for pull requests into any branch. Package APIs, storage formats, storage behavior and version 5.0.1 stay unchanged. Only the build_runner dev constraint rises; the limits of runtime dependencies stay.

## Repository context

Owners: `pubspec.yaml` and both lockfiles (dependencies), `hard-eng.gates.json` (the check list) and this plan. The three runtime updates fit inside the existing constraints. build_runner 2.17.1 needs a raised dev constraint and moves build and source_gen with it. Loops in `lib/src` move to one internal helper file, `lib/src/utils/concurrency.dart`: independent reads use `mapWithConcurrency` (results keep input order); writes, closes and box opens keep their order through `inOrder`. `publish.yml` gets the right version comment on its pinned action. The three `tool` files only run and check the browser download test (the gate runs the driver, which compiles the case for Chrome and maps its coverage), so they are test code: they move to `test/browser`, and the gate command, the format paths, the design note and the test import follow. The Flutter workflow owns required CI; the version-tag publisher stays unchanged.
Same cause: N/A — the freshness check is new here and no earlier fix of this cause exists.
Single source: `lib/src/utils/concurrency.dart` owns bounded reads (`mapWithConcurrency`) and ordered steps (`inOrder`). Searched `lib`, `test/browser` and `example/lib` for awaits in loops with the Semgrep speed rules: no other copy and no loop is left. The browser harness has one owner, `test/browser`; the gate command, format paths and design note point there.

## Decisions + authorization

Blockers: None
Handoff: Approval
Authority: The coordinator asked for the package updates and the repair needed to take the newest Hard Eng release. This change adds no package publication or app distribution.

## Acceptance + steps

- [x] The lockfiles resolve the four packages under `--enforce-lockfile`: N/A — a lock change; the native gate resolves and builds with the lockfiles.
- [x] The freshness check lists no outdated direct dependency: N/A — the native gate runs the check.
- [x] The security scan reports no speed finding, and zizmor reports no pin finding: N/A — the native gate runs both scans.
- [x] Helper limit and order, chunk order, missing-chunk error and box lookup order are proven by tests: `test/src/utils/concurrency_test.dart::never runs more tasks at once than the limit`, `test/src/utils/concurrency_test.dart::finishes each step before it starts the next one`, `test/src/storage/file_operations_test.dart::joins chunks in index order when earlier chunks load last`, `test/src/storage/file_operations_test.dart::names the missing chunk when one chunk is not stored` and `test/src/vault_storage_lookup_and_files_test.dart::lists ambiguous boxes in opening order and reads a lone custom hit`.
- [x] Package and example analysis, tests, coverage, dependency and workflow checks pass: N/A — storage behavior is unchanged; the native gate runs the existing tests.

## Baseline + execution

Result: Passed
Evidence: The check on the default branch stopped with `missing mandatory checks: freshness`; no package check ran. With the freshness check added, the gate failed only in the security scan (16 speed findings: 14 await-in-loop or sequential-await in `lib`, 2 regex in `tool`) and in zizmor (1 pin comment); all other gates passed. Before the update, `flutter pub outdated` named freerasp, hive_ce, web and build_runner as outdated direct or dev dependencies.
Execution: One coordinator updates the packages with `flutter pub upgrade`, adds the freshness check, repairs each finding in its own commit, then runs the native gate.

## Risks + recovery

The updates are minor and patch releases. Web chunk reads now run up to four at a time, so a failure in one chunk can end the read before a lower chunk is checked; the result and the error text for a single bad chunk stay the same. Revert the commits one by one if a regression appears.

## ux_reference

N/A — no package or example user interface changed.

## Verification

Result: Passed
Evidence: The native gate passed on the repaired branch: lockfile, format, strict analysis, tests and line coverage (package 81.94%, example 74.74%, minimum 70%), browser-download behavior, Dart Decimate, both performance budgets, secret scans, Actionlint, Zizmor, Shellcheck, OSV, freshness and Semgrep. PANA was not run locally; the PANA job runs on the pull request.
E2E: N/A — no package API or user flow changed; existing package, browser-download and example behavior tests remain required in the native gate.

Retro: The speed-rule findings and the comment-block findings were old code that no earlier check run had scanned: HE-HOT-PATH and HE-COMMENT-LINES, both enforced by the native gate. The missing freshness check and the outdated packages: the freshness check now in `hard-eng.gates.json`. The pin comment: the Zizmor check. Code outside the listed sources: the sources check of the gate. No Hard Eng fault.

Delivery target: Merge
Delivery: Pending — verify the scoped branch, required checks at its exact head, merge, and verify main CI.
