## 0.0.1

* Initial release of the `vault_storage` package.
* Provides secure key-value and file storage using Hive and `flutter_secure_storage`.
* Features include:
  - Dual storage model for key-value pairs and file blobs.
  - AES-GCM encryption for all sensitive data.
  - Cryptographic operations offloaded to background isolates.
  - Type-safe error handling with `fpdart`.
  - Riverpod provider for easy dependency injection.
