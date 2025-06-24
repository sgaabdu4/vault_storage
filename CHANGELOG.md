## 0.1.1

* refactor: Remove export of unused storage_keys constant from vault_storage.dart
* chore: Update build_runner dependency to version 2.5.4 in pubspec.yaml
* chore: Update _fe_analyzer_shared and analyzer versions in pubspec.lock
* test: Refactor error handling tests to use async/await for improved readability

## 0.1.0

### ✨ Major Features
* **feat: Add support for normal file storage** - Complete implementation with save, retrieve, and delete functionalities
* **feat: Add JsonSafe utility** - Safe JSON encoding and decoding with comprehensive error handling
* **feat: Enhance storage functionality** - New task execution system with improved error handling architecture

### 🔧 Core Improvements
* **feat: Add safe JSON encoding and decoding extensions** - Improved error handling for JSON operations
* **feat: Implement normal file storage** - Full file storage capabilities with proper error handling
* **feat: Improve error handling during storage initialization** - Detailed error display and better user feedback

### 🧪 Testing & Quality
* **test: Add comprehensive unit tests for VaultStorage service lifecycle** - Complete lifecycle management testing
* **test: Add TaskExecutor mock for testing** - Enhanced testing capabilities for task execution logic
* **test: Implement comprehensive StorageError class tests** - Ensures proper error handling across the package
* **test: Add tests for FileOperations and Encryption Helpers** - Validates core functionality with thorough coverage
* **test: Update VaultStorageImpl tests** - Utilize new extensions for JSON operations
* **refactor: Remove outdated test files** - Streamlined test suite by removing `vault_storage_impl_test.dart`
* **refactor: Consolidate storage keys tests** - Improved test organization

### 📚 Documentation & Examples
* **docs: Add comprehensive use cases section** - Healthcare, financial, enterprise, and consumer app examples
* **docs: Add production use disclaimers** - Important security and legal considerations for production apps
* **docs: Add platform setup requirements** - Detailed setup instructions for all supported platforms
* **docs: Enhance troubleshooting section** - Common issues and solutions for initialization problems
* **example: Improve error handling in example app** - Better error display and recovery mechanisms

### 🔒 Security & Compliance
* **security: Add production use disclaimers** - Clear security limitations and audit requirements
* **platform: Add macOS entitlements documentation** - Required keychain access setup for macOS apps

## 0.0.4

* refactor: Rename storageService to vaultStorage for consistency in README and tests
* chore: Update README for web compatibility and usage improvements
* docs: Clarify Riverpod dev version requirement and that generated files are included
* docs: Improve code examples and error handling documentation
* docs: Add comprehensive usage examples for both key-value and secure file storage

## 0.0.3

* fix: Update conditional imports for web compatibility in vault_storage_impl.dart, from dart.library.html to dart.library.js_interop

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

