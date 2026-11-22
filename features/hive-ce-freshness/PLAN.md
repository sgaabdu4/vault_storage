# Upgrade Hive CE Lockfile Dependencies

Status: Complete

## Outcome + scope

Upgrade `hive_ce` (`2.23.3` → `2.24.0`) across `pubspec.lock` and `example/pubspec.lock` and `hive_ce_flutter` (`2.5.0` → `2.6.0`) in root `pubspec.lock` (while `example/pubspec.lock` keeps `hive_ce_flutter` `2.3.4` per `example/pubspec.yaml`'s `>=2.3.4 <2.4.0` constraint) to clear the Hard Eng `freshness` baseline failure on `main`.

Non-goals: API changes, `pubspec.yaml` constraint changes, or UI edits.

## Sources + coverage

Sources: N/A — Hard Eng `freshness` gate on `origin/main` (`d73a5c3d`) requested this baseline repair.
Deliverables: None

## Repository context

Owners:
- `pubspec.lock` and `example/pubspec.lock` hold pinned dependency versions resolved by `flutter pub upgrade --major-versions --unlock-transitive hive_ce hive_ce_flutter`.

Same cause: Outdated `hive_ce` and `hive_ce_flutter` lockfile entries block `freshness` on `main`.
Single source: `pubspec.lock` and `example/pubspec.lock`.

## Decisions + authorization

Blockers: None
Handoff: None
Authority: Autonomous. Maintainer's 2026-11-22 rollout authorization covers baseline freshness repairs needed to keep `main` green.

## Acceptance + steps

- [x] Root `pubspec.lock` resolves `hive_ce` (`2.24.0`) and `hive_ce_flutter` (`2.6.0`), and `example/pubspec.lock` resolves `hive_ce` (`2.24.0`) while keeping `hive_ce_flutter` (`2.3.4`) per `example/pubspec.yaml` (`>=2.3.4 <2.4.0`), with zero `freshness` or vulnerability findings → N/A — Hard Eng `freshness`, `lockfile`, `vulnerabilities`, browser download coverage, and root + example test suites pass.

## Baseline + execution

Result: Passed
Evidence: `flutter pub upgrade --major-versions --unlock-transitive hive_ce hive_ce_flutter` updated `pubspec.lock` and `example/pubspec.lock` without modifying `pubspec.yaml`.
Execution: Single baseline-repair branch from `origin/main`; local build checks passed, while independent `challenge`, PR, CI, and merge remain pending.

## Risks + recovery

Dependency patch/minor upgrades could break storage tests, Dart-to-JS web download compilation, or downstream WebAssembly builds resolving `hive_ce_flutter` `2.6.0`. Local checks (`dart-test`, `example/dart-test`, and headless Chrome Dart-to-JS `browser-download-coverage`) verify VM and JS behavior. WebAssembly compatibility was verified with a temporary Flutter app (`dependencies: vault_storage: {path: <this checkout>}, hive_ce_flutter: ^2.6.0`) whose `lib/main.dart` calls `WidgetsFlutterBinding.ensureInitialized(); final storage = VaultStorage.create(); await storage.init();`: `flutter pub get` resolved `hive_ce 2.24.0`, `hive_ce_flutter 2.6.0`, and `vault_storage 6.0.0`, and `flutter build web --wasm` exited `0` (`✓ Built build/web`). Recovery: revert the merge commit on `main`.

## ux_reference

N/A — lockfile-only dependency bump; no UI files changed.

## Verification

Result: Passed
Evidence: Full `python3 .hooks/hard-eng.py check --base origin/main --plan-stage Complete` passed across root and `example/` packages including `freshness`, `vulnerabilities`, `browser-download-coverage`, and unit/performance tests.
E2E: N/A — lockfile-only dependency bump with no UI or API changes; browser download test verifies headless Chrome behavior.
Real service: N/A — local storage package makes no outside service calls.
Retro: None — routine baseline dependency repair.
Delivery target: Merge
Delivery: Pending — checks, challenge, PR, CI, and merge to `main`.
