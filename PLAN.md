# Storage refactor and dependency release

Status: Complete

## Outcome + scope

Release updated compatible dependencies after refactoring storage internals and adapting the installed Hard Eng checks. Preserve public APIs, existing stored data and platform behavior.

## Repository context

Owners: `lib/src/storage/file_operations.dart`, `lib/src/vault_storage_impl.dart`, `example/lib/main.dart`, `test/`, `hard-eng.gates.json`, `.github/workflows/flutter.yml`, `pubspec.yaml`, `CHANGELOG.md`.

## Decisions + authorization

Blockers: None
Handoff: Approval
Authority: User requested latest dependencies, refactor before release, current checkout, latest Hard Eng, tests and push to origin/main. Package publication is authorized. Consumer app distribution is excluded.

## Acceptance + steps

- [x] Shorten storage and example functions while preserving encryption, chunk framing, keys, metadata and error behavior.
- [x] Update dependencies and changelog; retain SDK-compatible versions.
- [x] Adapt project documentation, native checks and existing release workflow to Hard Eng without duplicate checks or hidden findings.
- [x] Pass analysis, formatting, full tests, coverage, boundaries, performance, security, dependency audit and PANA.

## Baseline + execution

Result: Passed
Evidence: Initial checks failed on PRODUCT.md structure, ten analyzer infos, six large functions and interface-signature duplication. These failures initiated the repair. The repaired baseline now passes its required categories; the initial failure above remains recorded. The browser report covers the missing executable helper.
Update: Installed CI-verified Hard Eng dcda0bba5eeea7d34ce27d914018ec1f899c8bc5. The published updater confirms no newer verified revision. Its classifier now correctly omits the bodyless interface from executable coverage; Chrome now supplies measured, source-mapped browser coverage which Flutter merges with the native report.
Migration: Removed the legacy override, old runtime scripts, stale copied Copilot rules and obsolete Claude output-style setting. Copilot and Claude resolve current AGENTS.md; all hooks use .hooks/hard-eng.py. The supported installer owns the current scaffold; project checks additionally run the Chrome helper and merge its coverage. No extra legacy skill directories remain.
Execution: One builder in the authorized current checkout. Refactor existing owners first, run focused tests, then adapt and run full gates. Preserve existing dependency work.

## Risks + recovery

Encrypted data must remain readable across versions. Existing compatibility and chunked-file tests protect the storage contract. Publication follows successful checks through the existing CI publisher only.

## ux_reference

N/A — internal refactor and dependency/tooling update; preserve the example's controls, labels and flow.

## Verification

Result: Passed
Evidence: 430 package tests and eight example tests pass. Strict analysis, formatting, boundary scans, actionlint, Zizmor, secret scans, OSV and Semgrep pass. PANA scores 160/160. Both performance budgets pass and intentionally zero budgets fail. Full suites run serially, matching the dedicated benchmarks, so competing test workers do not invalidate the unchanged five-second budget. The boundary rule passes an allowed import, rejects a forbidden implementation import and passes after restoration. Published Dart Decimate 0.0.45 passes both packages with zero findings after removing the obsolete suppression. Browser downloads pass with real bytes, MIME types, filenames, anchor removal and URL revocation; a deliberately leaked URL fails and emits no coverage. Nested unexecuted browser ranges retain zero counts. Native and Chrome coverage merge successfully. The clean-checkout pre-push check exposed ignored lockfiles; root and example lockfiles are now tracked and CI enforces them, while package publication continues to exclude them. All required check categories passed; the analyzer-only redundant default arguments were removed and strict analysis passed again. The final integrated Complete gate verifies this result before shipping.
E2E: Passed — existing tests exercise legacy-data reads and storage round trips. Added tests exercise native encrypted streaming and the example's save, get, delete, clear, file-picker cancellation and clipboard flows. Baseline and final example renders are identical at an 800 by 600 viewport in ready and saved states. Platform channels are mocked in these tests; consuming apps still need their device release validation.

Delivery target: Merge
Delivery: Pending — main CI plus automatic package publishing must be verified.
