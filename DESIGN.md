# Vault Storage Design

## Overview

`VaultStorage` exposes `IVaultStorage`. `VaultStorageImpl` coordinates Hive boxes, key-value serialization, file metadata and optional mobile security checks. Consumers use the public library exports.

## Components

- `interface/` defines contracts; implementations depend on contracts, never the reverse.
- `entities/`, `enum/` and `constants/` hold configuration, encryption inputs and storage identifiers.
- `storage/` owns serialization, adapters, encryption and native/web file operations.
- `security/` handles optional mobile threat detection. Platform-specific imports use native or web-compatible implementations.
- `extensions/` validates and converts metadata at storage boundaries.
- `example/` demonstrates the public package API. Tests cover storage behavior and compatibility independently of the example UI.

## Do's and Don'ts

- Preserve public signatures, adapter identifiers, stored keys and chunk framing across compatible releases.
- Keep encryption keys in secure storage and ciphertext in the selected file or Hive backend.
- Keep platform I/O behind conditional imports; maintain web and Wasm compatibility.
- Close stream resources on success and failure. Preserve typed storage errors.
- Do not import storage implementations into interfaces or data/configuration entities.
- Do not log user data, encryption keys or file contents.

## Verification

Native Flutter tests cover storage and the example. `dart run tool/browser_coverage.dart` checks browser downloads in isolated headless Chrome, including bytes, MIME types, filenames and cleanup. It maps measured V8 ranges through the Dart compiler source map; Flutter merges this report with native coverage using `--merge-coverage`. Chrome and `lcov` are required for this check.
