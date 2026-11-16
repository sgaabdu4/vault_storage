# Make the package pass Hard Eng's strict rules

Status: Draft

## Outcome + scope

The package and its example pass the new Hard Eng rules for switch-offs, code comments, named Markdown files, flutter_skill_lints 0.14.0 and dart-decimate 0.0.76, with no test removed that proves behavior. Non-goals: a package version change and any change of library behavior.

## Repository context

Owners: `lib/`, `test/`, `example/`, `analysis_options.yaml`, `example/analysis_options.yaml`, `.dart-decimaterc.json`, `README.md`, `test/README.md`.
Same cause: N/A — first pass of these rules in this project.
Single source: N/A — no rule, value or type changes owner.

## Decisions + authorization

Blockers: The flutter_skill_lints 0.14.0 findings that remain need an owner decision. Classes that change the public API or stored types (typed errors thrown by the API, dynamic JSON values, demo-app localization) and the config rules that demand riverpod_lint, an errors section and an arb exclude are not fixed. The plan cannot be Ready until the owner decides.
Handoff: Approval
Authority: The owner asked for every project to pass the strict rules (2026-11-16); the coordinator assigned this project.

## Acceptance + steps

- [ ] No `// ignore` stays in tests -> `test/src/vault_storage_security_validation_test.dart::AmbiguousKeyError should store key and foundInBoxes`, runs and passes without the ignore.
- [ ] No narration comment block stays in lib, test or release.sh -> `python3 .hooks/hard-eng.py check` reports no comment-block finding.
- [ ] Both unnamed Markdown files have a reader -> `python3 .hooks/hard-eng.py check` reports no unnamed-Markdown finding.
- [x] FreeRASP 9 configuration is built correctly -> `test/src/security/talsec_config_test.dart::androidConfigFor passes the given package name and certificate hashes`.
- [x] Example failure messages stay the same -> `example/test/initialization_failure_test.dart::a jailbreak gets its own warning`.
- [ ] The library behaves as before -> `flutter test` in the package root passes with every test kept.

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
Evidence: Run 1, own hooks, Flutter 3.50.0: every gate passes except the analyzer gates (flutter_skill_lints findings) and the 8 MiB timing test, which took 5.2 to 8.9 s on a busy machine (the base branch took 5.17 s). Run 2, develop hooks: same, plus dart-decimate reading the starter pubspec in the develop .agents folder. Run 3, dart-decimate 0.0.76 by hand: both packages pass at CRAP 30. Final proof runs: Pending.
E2E: N/A — no user journey changes; the package and example tests cover the behavior.
Retro: Pending

Delivery target: Merge
Delivery: Pending — PR merged into main with every required check passing.
