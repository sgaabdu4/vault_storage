# Make the package pass Hard Eng's strict rules

Status: Complete

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

- [x] No `// ignore` stays in tests -> `test/src/vault_storage_lifecycle_and_custom_boxes_test.dart::should store key and foundInBoxes`, runs and passes without the ignore.
- [x] No narration comment block stays in lib, test or release.sh -> N/A — proved by the Hard Eng comment check in the gate, no project test fits.
- [x] Both unnamed Markdown files have a reader -> N/A — proved by the Hard Eng named-Markdown check in the gate, no project test fits.
- [x] FreeRASP 9 configuration is built correctly -> `test/src/vault_storage_impl_test.dart::androidConfigFor passes the given package name and certificate hashes`.
- [x] Example failure messages stay the same -> `example/test/initialization_failure_test.dart::a jailbreak gets its own warning`.
- [x] The four public API breaks ship as 6.0.0 -> `test/src/constants/vault_storage_config_test.dart::keeps every custom value`, `test/src/extensions/storage_extensions_test.dart` low threshold cases and the CHANGELOG 6.0.0 section.
- [x] The example builds for web -> N/A — proved by the `Build example for web` CI job and a local `flutter build web` of the example, no unit test can run a build.
- [x] The changelog and the README list all nine breaks with a migration line each -> N/A — documentation, checked by reading CHANGELOG.md and README.md against the `5.x` diff.
- [x] Data written by 5.x reads back -> `test/src/v5_data_compatibility_test.dart::reads small and streamed secure files and normal files`.
- [x] `VaultStorage.create` passes the config on -> `test/vault_storage_test.dart::passes the given config to the storage and to its file operations`.
- [x] `getFile` keeps the 5.x error for broken file metadata -> `test/src/vault_storage_lifecycle_and_custom_boxes_test.dart::throws VaultStorageSerializationError for broken normal file metadata`.
- [x] A streamed secure web file reads back after its box reloads -> `test/src/web_stream_reload_test.dart::reads back every byte`.
- [x] Type mismatch errors hold no stored value -> `test/src/error_message_secrecy_test.dart::a secure box text value that does not fit the type names only the key and types`.
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

Result: Passed
Evidence: The owner's review (2026-11-17) added six items, each with a failing check first. (1) The example failed `flutter build web` with "Attempted to generate localizations code without having the flutter: generate flag turned on"; the flag is set, the generated localization files are no longer committed or edited, they are written under `.g.dart` names that the canonical analysis exclude covers (the unused `cupertino_ui` dependency, only needed by the old hand edit, is gone), and the CI job `Build example for web` runs the build. (2) The changelog and the README list nine breaks, each with a migration step. (3) A fixture written at commit c25a4413 by `test/fixtures/v5/generate_v5_fixture.dart.txt` reads back; flipping the chunk header byte order in `secure_chunks.dart` fails the streamed secure file test. (4) The config hand-off test fails when either hand-off in `create` is removed (both mutations run). (5) `getFile` throws `VaultStorageSerializationError` again; the two new tests failed first with `VaultStorageReadError`. (6) The web read of a streamed secure file after the metadata box reloads failed with a range error before the fix (real Hive reload on the Dart VM, because the test uses `dart:io`, so no Chrome run), and the secure-value error text test failed before the fix. Runs: root `flutter test` 464 passed and example 15 passed; `flutter analyze` is clean in both packages on two runs; `flutter build web` of the example succeeded; `dart pub publish --dry-run` reports 0 warnings. flutter_skill_lints is pinned at ^0.15.1. Tests removed earlier: the old mutability and scenario tests of the static `VaultStorageConfig` died with the statics; `vault_storage_config_test.dart` and the low-threshold cases in `storage_extensions_test.dart` prove the same thresholds on an instance. Re-review (2026-11-17): JSON, number and base64 decode errors carry a fixed cause text (the secrecy tests check the exact text and run in Chrome in the CI job `Error secrecy in Chrome`); nested map keys of app data stay as stored, and only file metadata is converted (test `keeps the non-text keys of a nested map as 5.x did`); the 5.x fixture test runs in a temp folder per run and rewrites the stored file paths with Hive; each had a red test first.
E2E: N/A — no user journey changes; the package and example tests cover the behavior.
Real service: N/A — the package calls no outside service; it stores data on the device only.
Retro: Hard Eng and CI failures in this task: plan Ready versus the Complete stage in CI, stale test names in acceptance lines, a screen text wall in the example arb, the held cfg findings. Prevention: None — the Hard Eng checks already refuse each one, and the cfg findings were an upstream flutter_skill_lints fault fixed in 0.15.1.

Delivery target: Merge
Delivery: Pending — PR merged into main with every required check passing.
