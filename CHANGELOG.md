## 0.0.2

* Added web compatibility for vault_storage package.
* Enhanced storage capabilities:
  - Added secure file storage with new Hive box.
  - Updated BoxType enum to support secure file storage.
  - Implemented platform-specific file storage handling.
* Improved error handling:
  - Added disposal error handling to IVaultStorage interface.
  - Enhanced error handling throughout the package.
* Added example project with pubspec.yaml demonstrating package usage.
* Code improvements:
  - Better formatting and code consistency.
  - Cleaned up unused code in test files.
  - Refactored implementation for better maintainability.

## 0.0.1

* Initial release of the `vault_storage` package.
* Provides secure key-value and file storage using Hive and `flutter_secure_storage`.
* Features include:
  - Dual storage model for key-value pairs and file blobs.
  - AES-GCM encryption for all sensitive data.
  - Cryptographic operations offloaded to background isolates.
  - Type-safe error handling with `fpdart`.
  - Riverpod provider for easy dependency injection.

