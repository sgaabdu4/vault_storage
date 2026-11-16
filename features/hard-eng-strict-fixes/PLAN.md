# Make the package pass Hard Eng's strict rules

Status: Ready

## Outcome + scope

The package and its example pass the new Hard Eng rules for switch-offs, code comments, named Markdown files, flutter_skill_lints 0.14.0 and dart-decimate 0.0.76, with no test removed that proves behavior. The owner decided (2026-11-16) to ship the four public API breaks as release 6.0.0: remove the seven deprecated error aliases, make `VaultStorageConfig` an immutable value passed to `VaultStorage.create`, make the two `VaultSecurityConfig` collections non-null, and make `IVaultStorage` an `abstract interface class`. Other library behavior stays the same.

## Sources + coverage

Sources: N/A — the request is the only source.

## Repository context

Owners: `lib/`, `test/`, `example/`, `analysis_options.yaml`, `example/analysis_options.yaml`, `.dart-decimaterc.json`, `README.md`, `test/README.md`.
Same cause: N/A — first pass of these rules in this project.
Single source: N/A — no rule, value or type changes owner.

## Decisions + authorization

Blockers: None
Handoff: Approval
Authority: The owner asked for every project to pass the strict rules (2026-11-16); the coordinator assigned this project.

## Acceptance + steps

- [x] No `// ignore` stays in tests -> `test/src/vault_storage_security_validation_test.dart::AmbiguousKeyError should store key and foundInBoxes`, runs and passes without the ignore.
- [x] No narration comment block stays in lib, test or release.sh -> N/A — proved by the Hard Eng comment check in the gate, no project test fits.
- [x] Both unnamed Markdown files have a reader -> N/A — proved by the Hard Eng named-Markdown check in the gate, no project test fits.
- [x] FreeRASP 9 configuration is built correctly -> `test/src/security/talsec_config_test.dart::androidConfigFor passes the given package name and certificate hashes`.
- [x] Example failure messages stay the same -> `example/test/initialization_failure_test.dart::a jailbreak gets its own warning`.
- [x] The four public API breaks ship as 6.0.0 -> `test/src/constants/vault_storage_config_test.dart::keeps every custom value`, `test/src/extensions/storage_extensions_test.dart` low threshold cases and the CHANGELOG 6.0.0 section.
- [x] The library behaves as before -> N/A — proved by the full `flutter test` run in the package root and in `example`, which keep every behavior test.

## Baseline + execution

Result: Passed
Evidence: Scan of the update commit found 2 switch-offs, 127 comment blocks and 2 unnamed Markdown files; `flutter test` passed 440 tests before and after the comment removal.
Execution: One builder, one slice per rule.

## Risks + recovery

Shortened public doc comments lose prose in the pub.dev API page. Recovery = revert the comment commit.

## ux_reference

N/A — no rendered interface changes.

## Verification

Result: Pending
Evidence: Held: the four `cfg_*` findings (cfg_strict_analysis, cfg_required_lints, cfg_generated_exclude, cfg_analysis_options_canonical) on `example/lib/main.dart` come from a fault in flutter_skill_lints 0.14.0 that 0.15.0 clears; 0.15.0 is not released, so the plan stays Ready and nothing is worked around. Run 1, own hooks, Flutter 3.50.0, `uv run --no-project --with pyyaml python p30-check.py <revision> Ready`: exit 1; every gate passes (lockfile, format, browser-download-coverage, secure-stream-performance, consumer-startup-performance, shellcheck, actionlint, vulnerabilities, secrets-history, secrets-files, freshness, zizmor, security, both dart-test runs at 92.74% and 87.64% line coverage, both dart-decimate runs) except example/dart-analyze and strict-types-lint, which report only those four findings. Run 2, develop hooks copied into a scratch copy without the starters folder: same result, exit 1, same four findings. Run 3, `npx -y dart-decimate@0.0.76 check . --threshold 0 --strict --format json` after `--version` printed 0.0.76: exit 0 in the package root and in `example`; `flutter test` passes 448 tests in the root and 15 in `example`. Tests removed: the old mutability and scenario tests of the static `VaultStorageConfig` died with the statics; the new `vault_storage_config_test.dart` and the low-threshold cases in `storage_extensions_test.dart` prove the same thresholds on an instance.
E2E: N/A — no user journey changes; the package and example tests cover the behavior.
Real service: N/A — the package calls no outside service; it stores data on the device only.
Retro: Pending

Delivery target: Merge
Delivery: Pending — PR merged into main with every required check passing.
