## 2.0.0

This release delivers a simpler, clearer API and improved performance characteristics. It replaces the BoxType/Either-based surface with intent-driven methods and exception-based error handling. File APIs are simplified to use your own keys instead of passing metadata around.

### Breaking Changes
* API surface reworked for simplicity:
  - Removed: `set(BoxType, key, value)` and `get<T>(BoxType, key)` in favor of intent-specific methods
  - Added: `saveSecure`, `saveNormal`, `get<T>(key, {bool? isSecure})`, `delete(key)`, `clearNormal()`, `clearSecure()`
  - File retrieval unified: `getFile(key, {bool? isSecure})` (replaces passing metadata to `getSecureFile`/`getNormalFile`)
  - File deletion unified: `deleteFile(key)`
* Error handling model:
  - Removed: `Either<StorageError, T>` return style
  - Added: Methods now throw `StorageError` subclasses (`StorageInitializationError`, `StorageReadError`, `StorageWriteError`, `StorageDeleteError`, `StorageDisposalError`, `StorageSerializationError`)
* Web file retrieval
  - Custom download filenames are no longer configurable via public API; sensible filenames are generated automatically based on stored extension

### New Features
* Simplified key-value API with smart lookup order (normal first, then secure) when `isSecure` is not specified
* Secure and normal file storage keyed by your own identifiers; implementation tracks metadata internally
* Large-file encryption streaming for secure files (chunked AES-GCM) to reduce memory pressure
* Performance configuration via `VaultStorageConfig` with thresholds for JSON/base64 isolate usage and secure file streaming
* More aggressive Hive compaction strategy for better on-disk efficiency

### Web Platform Behavior
* Auto-downloads when calling `getFile()` on web; returns `Uint8List` and triggers browser download with a smart filename
* MIME type inference from file extension for better browser handling

### Internal Improvements
* Consistent use of isolates for heavy crypto, JSON encode/decode, and base64 encode/decode
* Clear separation of responsibilities: `IVaultStorage` (interface) and `VaultStorageImpl` (implementation), with `VaultStorage.create()` factory
* File operations abstracted behind `IFileOperations` for testability

### Migration Notes
1. Initialization and errors
   - Before: `await storage.init()` returned `Either`; handled with `.fold()`
   - After: `await storage.init()` throws on failure. Use try/catch around initialization and calls.

2. Key-value operations
   - Replace `set(BoxType.secure, 'k', 'v')` with `saveSecure(key: 'k', value: 'v')`
   - Replace `set(BoxType.normal, 'k', 'v')` with `saveNormal(key: 'k', value: 'v')`
   - Replace `get<T>(BoxType.secure, 'k')` with `get<T>('k', isSecure: true)`
   - Replace `get<T>(BoxType.normal, 'k')` with `get<T>('k', isSecure: false)`
   - Delete both: `delete('k')`; clear with `clearNormal()` / `clearSecure()`

3. File storage
   - Replace metadata-based retrieval (`getSecureFile(fileMetadata: ...)`) with key-based retrieval: `getFile('myKey')`
   - Saving files now requires a key: `saveSecureFile(key: 'myKey', fileBytes: ..., originalFileName: 'x.jpg')`
   - Delete with `deleteFile('myKey')`
   - Web downloads still occur automatically on retrieval; custom filenames are not exposed

Refer to the README Migration Guide for full examples.

## 1.2.1

### New Features
* **feat: Automatic file downloads on web platforms** - `getSecureFile()` and `getNormalFile()` now automatically trigger downloads in web browsers while maintaining native platform behavior
* **feat: Custom download filenames** - Added optional `downloadFileName` parameter to file retrieval methods for custom web download names
* **feat: Smart filename generation** - Automatically generates appropriate filenames using stored file extensions (e.g., `document.pdf`, `image.jpg`)
* **feat: MIME type detection** - Automatic MIME type detection for 15+ common file formats ensures proper browser handling

### Technical Improvements
* **feat: Modern web standards** - Migrated from deprecated `dart:html` to modern `package:web` APIs for future WebAssembly (Wasm) compatibility
* **feat: Enhanced metadata storage** - File extensions are now stored in metadata for both secure and normal files
* **feat: Conditional imports optimization** - Updated to use `dart.library.js_interop` for better web/native platform detection

### Documentation Updates
* **docs: Enhanced README with web download examples** - Added comprehensive examples showing platform-specific behavior
* **docs: Platform behavior comparison table** - Clear documentation of differences between web and native platforms
* **docs: MIME type support documentation** - Listed all supported file types and their automatic MIME type mappings

### 🔄 Backward Compatibility
* **No breaking changes** - All existing code continues to work without modifications
* **Optional parameters** - New features use optional parameters to maintain API compatibility
* **Same return types** - Methods still return `Either<StorageError, Uint8List>` as before

### Web Platform Enhancements
* **Web downloads**: Files automatically download when retrieved on web platforms
* **Smart filenames**: Uses original file extensions for meaningful download names
* **MIME type support**: PDF, images, documents, audio, video, and more
* **Custom naming**: Optional custom filenames for downloads

### Dependencies
* **Added**: `web: ^1.1.1` for modern web API access

## 1.1.0

### Bug Fixes
* **fix: Android compilation issues** - Fixed Android build failures by migrating from unmaintained `cryptography` package to actively maintained `cryptography_plus` 
* **fix: AGP 8.x compatibility** - Resolved Android Gradle Plugin 8.x compatibility issues that prevented compilation on newer Android projects

### Dependency Updates
* **feat: Replace cryptography with cryptography_plus** - Migrated from `cryptography: ^2.7.0` to `cryptography_plus: ^2.7.1` to ensure ongoing maintenance and Android compatibility
* **feat: Upgrade flutter_secure_storage** - Updated from `^9.2.4` to `^10.0.0-beta.4` for latest security improvements and bug fixes

### Migration Notes
* **Automatic migration**: No code changes required - the package handles the cryptography library migration internally
* **Android compatibility**: Projects that previously failed to compile on Android with AGP 8.x will now work correctly
* **Breaking changes**: None for end users - all public APIs remain the same

## 1.0.1

### Documentation Improvements
* **docs: Fix incorrect parameter name in README.md** - Corrected `metadata:` to `fileMetadata:` in `getSecureFile` method example
* **docs: Fix version inconsistencies** - Updated all version references from `^0.1.1` to `^1.0.0` to match current package version
* **docs: Fix Riverpod integration example** - Corrected error handling in main.dart to use try-catch instead of incorrect `.fold()` usage
* **docs: Fix syntax errors** - Removed duplicate closing braces and fixed code formatting issues

### Technical Fixes
* **fix: Correct API usage examples** - All code examples now use the correct method signatures and parameter names
* **fix: Improve error handling patterns** - Better distinction between functional error handling (Either) and exception-based error handling (try-catch)

## 1.0.0

### Breaking Changes
* **BREAKING: Remove built-in Riverpod provider** - The package no longer includes a built-in Riverpod provider to remain framework-agnostic
* **BREAKING: Hide implementation details** - Use `VaultStorage.create()` factory method instead
* **feat: Framework-agnostic design** - Users can now integrate with any state management solution or use the service directly

### New Features
* **feat: Add VaultStorage.create() factory method** - Clean API that returns `IVaultStorage` interface, hiding implementation details
* **feat: Improved API design** - Only the interface (`IVaultStorage`) is exposed to users, making the API cleaner and less confusing

### Documentation Improvements
* **docs: Add comprehensive state management integration examples** - Includes examples for Riverpod and direct usage
* **docs: Update initialisation examples** - Show how to initialise the service without Riverpod dependency
* **docs: Clarify framework-agnostic approach** - Emphasise that the package works with any state management solution
* **docs: Update all examples to use factory method** - Consistent API usage throughout documentation

###  Migration Guide
**From built-in Riverpod provider:**
If you were using the built-in `vaultStorageProvider`, you can easily recreate it in your own project:

1. Add Riverpod dependencies to your `pubspec.yaml`
2. Create your own provider file following the examples in the README
3. Update your initialisation code to use your custom provider

**From VaultStorageImpl():**
Replace direct instantiation with the factory method:
```dart
// Before
final storage = VaultStorageImpl();

// After
final storage = VaultStorage.create();
```

This change makes the package more flexible, reduces its dependency footprint, and provides a cleaner API.

## 0.1.1

* refactor: Remove export of unused storage_keys constant from vault_storage.dart
* chore: Update build_runner dependency to version 2.5.4 in pubspec.yaml
* chore: Update _fe_analyzer_shared and analyzer versions in pubspec.lock
* test: Refactor error handling tests to use async/await for improved readability

## 0.1.0

### Major Features
* **feat: Add support for normal file storage** - Complete implementation with save, retrieve, and delete functionalities
* **feat: Add JsonSafe utility** - Safe JSON encoding and decoding with comprehensive error handling
* **feat: Enhance storage functionality** - New task execution system with improved error handling architecture

### Core Improvements
* **feat: Add safe JSON encoding and decoding extensions** - Improved error handling for JSON operations
* **feat: Implement normal file storage** - Full file storage capabilities with proper error handling
* **feat: Improve error handling during storage initialisation** - Detailed error display and better user feedback

### Testing & Quality
* **test: Add comprehensive unit tests for VaultStorage service lifecycle** - Complete lifecycle management testing
* **test: Add TaskExecutor mock for testing** - Enhanced testing capabilities for task execution logic
* **test: Implement comprehensive StorageError class tests** - Ensures proper error handling across the package
* **test: Add tests for FileOperations and Encryption Helpers** - Validates core functionality with thorough coverage
* **test: Update VaultStorageImpl tests** - Utilise new extensions for JSON operations
* **refactor: Remove outdated test files** - Streamlined test suite by removing `vault_storage_impl_test.dart`
* **refactor: Consolidate storage keys tests** - Improved test organisation

### Documentation & Examples
* **docs: Add comprehensive use cases section** - Healthcare, financial, enterprise, and consumer app examples
* **docs: Add production use disclaimers** - Important security and legal considerations for production apps
* **docs: Add platform setup requirements** - Detailed setup instructions for all supported platforms
* **docs: Enhance troubleshooting section** - Common issues and solutions for initialisation problems
* **example: Improve error handling in example app** - Better error display and recovery mechanisms

### Security & Compliance
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

