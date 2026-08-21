# Vault Storage

Secure local key-value and file storage for Flutter apps across mobile, web, and desktop.

## Users

Flutter teams that need one API for normal local data, encrypted local data, and files without maintaining separate storage and encryption systems.

## Purpose

Store and retrieve app data locally with clear secure and normal operations, consistent errors, optional Android and iOS runtime security checks, and support for large encrypted files.

## Boundaries

- Not remote storage, synchronization, backup, or account management.
- Runtime jailbreak and tampering checks apply only to Android and iOS.
- Release 5.x requires Dart 3.10 or later and Flutter 3.38 or later.

## Success

| Outcome | Metric | Target |
|---|---|---|
| Storage behavior remains reliable | Full package test suite | Zero failures on each release |
| Package stays ready for Pub | Pana package score | 160 out of 160 |
| Supported dependencies stay current | Direct dependency review | Latest stable compatible versions |

## Evidence

- Public operations and behavior = `lib/src/interface/i_vault_storage.dart`
- SDK and dependency limits = `pubspec.yaml`
- Platform setup and usage = `README.md`
- Released changes = `CHANGELOG.md`
- Behavior checks = `test/`

## Unknowns

- Each consuming app's platform permissions and entitlements = settled by that app's device tests and release checks.
