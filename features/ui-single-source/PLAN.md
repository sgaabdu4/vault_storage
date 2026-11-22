# Prepare Vault Storage for Hard Eng UI Single Source of Truth

Status: Complete

## Outcome + scope

Prepare `sgaabdu4/vault_storage` for Hard Eng's UI Single Source of Truth (`b5`) and `flutter_skill_lints ^0.16.0` without changing visible UI appearance or modifying `hard-eng.gates.json`:
1. Bump `flutter_skill_lints` from `^0.15.1` to `^0.16.0` in `analysis_options.yaml` and `example/analysis_options.yaml`.
2. Centralize the five raw Material controls used by `example/lib/demo/` (`ElevatedButton`, `TextButton`, `AlertDialog`, `TextField`, `DropdownButtonFormField`) into shared widgets under `example/lib/core/widgets/`.
3. Add YAML token front matter to `DESIGN.md` matching `example/lib/design/app_theme.dart`, add `UI-LIBRARY.md`, and add accessibility guideline widget tests covering all changed example controls and dialogs.

Non-goals: adding `"ui_library"` to `hard-eng.gates.json` (added after `b5` releases), changing storage package APIs, or altering visual appearance.

## Sources + coverage

Sources: N/A — the maintainer's UI single-source rollout authorization and live `b5` / `flutter_skill_lints ^0.16.0` analyzer findings define the scope.
Deliverables: None

## Repository context

Owners:
- `example/lib/core/widgets/` (`AppDialog`, `AppDropdownField`, `AppElevatedButton`, `AppTextButton`, `AppTextField`) owns shared base controls for the example app.
- `example/lib/demo/demo_button.dart` and `example/lib/demo/dialogs/*.dart` compose those shared controls.
- `example/lib/design/app_theme.dart` owns theme color tokens mirrored in `DESIGN.md`; `UI-LIBRARY.md` catalogs `example/lib/core/widgets/**`.

Same cause: All 14 `ui_base_control_outside_library` analyzer errors in `example/lib/demo/` stemmed from raw Material controls outside `example/lib/core/widgets/`; all 14 are migrated together.
Single source: `example/lib/core/widgets/**` for base controls; `example/lib/design/app_theme.dart` and `DESIGN.md` for color tokens.

## Decisions + authorization

Blockers: None
Handoff: None
Authority: Autonomous. Maintainer's 2026-11-22 UI Single Source of Truth rollout authorization covers the refactor, PR, merge, and delivery verification on `main`.

## Acceptance + steps

- [x] `analysis_options.yaml` and `example/analysis_options.yaml` pin `flutter_skill_lints: ^0.16.0` with zero analyzer issues → N/A — `dart analyze --fatal-infos .` in root and `example/` passes with zero issues.
- [x] All 14 raw Material control calls in `example/lib/demo/` route through `example/lib/core/widgets/` with zero `b5` hits → N/A — `b5` `ui_whole.ui_findings_whole` reports `0` findings for `["example/lib/core/widgets/**"]`.
- [x] Changed example widgets and dialogs pass all four Flutter accessibility guidelines and preserve identical rendered output → `example/test/core/widgets_accessibility_test.dart::shared controls meet contrast and tap-target guidelines` and `example/test/core/widgets_accessibility_test.dart::demo dialogs meet contrast and tap-target guidelines` pass all four `meetsGuideline` checks and before/after web captures match byte for byte at 390, 768, and 1280 px.

## Baseline + execution

Result: Passed
Evidence: On `origin/main` (`d73a5c3d`), bumping `flutter_skill_lints` to `^0.16.0` produced 14 `ui_base_control_outside_library` errors in `example/lib/demo/` and `b5` reported 3 missing UI-library / `DESIGN.md` front-matter items. Extracting the five shared widgets, updating the seven callers, adding `UI-LIBRARY.md` and `DESIGN.md` front matter, and adding accessibility widget tests cleared all findings.
Execution: Single builder in isolated clone: update `flutter_skill_lints` pins, create `example/lib/core/widgets/**`, migrate callers, add accessibility tests and docs, capture before/after web builds, run full Hard Eng `check` and `challenge`.

## Risks + recovery

Wrapping Material controls could shift keys or dialog behavior; existing `example/test/app/my_app_test.dart` interactive tests, new accessibility guideline tests, and byte-identical before/after web captures cover both. Recovery: revert the merge commit on `main`.

## ux_reference

N/A — unchanged: ![Before](.hard-eng/browser/before-1280.png) ![After](.hard-eng/browser/after-1280.png) — Vault Storage example demo app web build.

## Verification

Result: Passed
Evidence: `dart analyze --fatal-infos .` passed in root and `example/` with `0` issues; `b5` whole-project UI single-source scan returned `0` hits for `["example/lib/core/widgets/**"]`; `flutter test` passed all example tests including `example/test/core/widgets_accessibility_test.dart`; before (`origin/main`) and after (`HEAD`) web captures matched byte for byte at 390, 768, and 1280 px; full `python3 .hooks/hard-eng.py check --base origin/main --plan-stage Complete` passed.
E2E: Passed — built and served the real Flutter web example for `origin/main` and `HEAD`, captured 390, 768, and 1280 px via `hard-eng.py browser capture` (byte-identical), and ran `example/test/app/my_app_test.dart` covering save/retrieve/delete/clear/storage-location flows.
Real service: N/A — local storage package and example UI make no outside service calls.
Retro: None — clean refactor with no recurring failures.
Delivery target: Merge
Delivery: Pending — checks, challenge, PR, CI, and merge to `main`.
