# Move the package to Flutter 3.50.0

Status: Complete

## Outcome + scope

The package and its example are analyzed, tested and checked with Flutter 3.50.0 and Dart 3.14.0, and the workflows use that release. Non-goals: a package version change, a change of the lowest supported Flutter and Dart versions, and any change of library code.

## Repository context

Owners: `example/lib/main.dart` and `example/test/storage_demo_test.dart` (the only files that import the old Material library), `example/pubspec.yaml`, `.github/workflows/flutter.yml` and `.github/workflows/publish.yml` (Flutter pins).
Same cause: N/A — first move to Flutter 3.50.0. Another project made the same move first; its notes gave the commands and the edit classes.
Single source: Flutter version pin. One value in three places, all changed in this branch. Searched `.github`, `pubspec.yaml` and the tests for the old version. The library has no Material or Cupertino import.

## Decisions + authorization

Blockers: None
Handoff: Approval
Authority: The owner approved the move of this project to Flutter 3.50.0 on 2026-11-12.

## Acceptance + steps

- [x] Analyzer reports no issue with Flutter 3.50.0 -> `dart analyze --fatal-infos .` in the package root, which includes the example. N/A — no test can prove an analyzer result; the strict-types-lint gate runs it.
- [x] The example still shows its storage location -> `example/test/storage_demo_test.dart::storage location displays the directory and copies its path`.
- [x] The example round-trips values and files through the public storage API -> `example/test/storage_demo_test.dart::$kind values can be saved, retrieved and deleted`.
- [x] The library behaves as before -> `test/vault_storage_test.dart::should create instance without security config` and the rest of `flutter test`.
- [x] Generated code is stable -> `dart run build_runner build` leaves `git status` clean. N/A — no test can prove generator output; the check compares the tree.

## Baseline + execution

Result: Passed
Evidence: With Flutter 3.50.0, `dart analyze --fatal-infos .` gave 2 `deprecated_member_use` infos, one in each example file that imports the old Material library. After the move it gives none.
Execution: One builder, one slice per commit: lockfiles, import move, workflow pins, generated file.

## Risks + recovery

The package version stays the same, so a push to main creates no tag and no publish. Recovery = revert the branch. The example look can differ where Flutter 3.50.0 changed Material widgets; no screen was inspected on a device.

## ux_reference

N/A — import move in the example app only; no rendered interface change was designed.

## Verification

Result: Passed
Evidence: `python3 .hooks/hard-eng.py check --plan-stage Complete --base origin/main` with Flutter 3.50.0 first on PATH exits 0.
E2E: N/A — no user journey changes; the package and example tests cover the behavior.

Delivery target: Merge
Delivery: Pending — PR merged into main with every required check passing.
