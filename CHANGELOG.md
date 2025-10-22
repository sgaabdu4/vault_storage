## [2.3.0] - 2025-10-22
### New Features
- **feat: Custom box support** - Create and manage multiple custom storage boxes with independent security configurations
- **feat: Box isolation** - Each custom box maintains separate encryption and storage, enabling multi-tenancy and data segregation
- **feat: Dynamic box management** - Add custom boxes at initialization with flexible configuration options
- **feat: BoxConfig entity** - Immutable configuration with Freezed for type-safe box definitions

### API Enhancements
- **feat: Enhanced create() factory** - Added optional `customBoxes` parameter to define additional storage boxes at creation
- **feat: Box parameter in storage methods** - All storage methods now accept optional `box` parameter to target specific custom boxes
- **feat: Factory method parameters** - VaultStorage.create() now supports customBoxes and storageDirectory parameters

### Documentation Updates
- **docs: Custom boxes usage guide** - Comprehensive examples for multi-tenant and isolated storage scenarios
- **docs: BoxConfig examples** - Configuration patterns for secure and normal custom boxes
- **docs: Migration examples** - Clear guidance for adopting custom boxes in existing applications

### Testing Improvements
- **test: Custom box comprehensive tests** - Full test coverage for custom box operations
- **test: Box isolation validation** - Ensure data segregation between boxes
- **test: BoxConfig entity tests** - Verify immutability and equality behavior

### Use Cases
- **Multi-tenant applications**: Separate storage per user or organization
- **Feature isolation**: Independent storage for different app features
- **Data categorization**: Organize data by type, sensitivity, or lifecycle
- **Workspace management**: Multiple workspaces with isolated data

### Backward Compatibility
- **No breaking changes** - Custom boxes are completely optional
- **Default behavior unchanged** - Existing code works without modification
- **Gradual migration** - Add custom boxes incrementally as needed

## [2.2.2] - 2025-10-13
### Dependency Updates
- **chore: Upgrade freerasp** - Updated from `^7.2.1` to `^7.2.2` for latest security improvements and bug fixes
- **chore: Upgrade hive_ce** - Updated from `^2.13.2` to `^2.15.0` for improved performance and stability

## [2.2.1] - 2025-09-21
### Web Compatibility Improvements
- **fix: Add WASM compatibility** - Implemented conditional imports for FreeRASP to ensure package works in WASM runtime
- **feat: FreeRASP mock implementation** - Added comprehensive mock for FreeRASP on unsupported platforms (Web, Windows, Linux, macOS)
- **improvement: Cross-platform stability** - Package now gracefully handles FreeRASP dependency across all platforms without breaking WASM compatibility

### Technical Improvements
- **refactor: Conditional imports for security features** - FreeRASP is only imported when `dart.library.io` is available
- **docs: Updated platform compatibility notes** - Clarified that security features work seamlessly across all platforms with automatic fallback

## [2.2.0] - 2025-09-21
### New Security Features
- **feat: Optional jailbreak protection with FreeRASP integration** - Add runtime security monitoring to protect your app and user data
- **feat: Comprehensive threat detection** - Detect jailbreak/root, app tampering, debugging, hooking frameworks, emulators, and more
- **feat: Flexible security configuration** - Three modes: development, production, and custom configurations
- **feat: Custom threat callbacks** - Handle each security threat with your own custom logic
- **feat: Granular blocking controls** - Choose which threats should block vault operations vs. just log/notify
- **feat: Security monitoring integration** - Optional integration with FreeRASP's monitoring dashboard
- **feat: Cross-platform compatibility** - Security features work on Android and iOS; gracefully ignored on other platforms

### Platform Support
- **important: Security features only available on Android and iOS** - FreeRASP integration requires mobile platforms
- **feat: Automatic platform detection** - Security initialization is skipped on unsupported platforms (macOS, Windows, Linux, Web)
- **feat: Unified codebase** - Same code works across all platforms without conditional logic

### API Enhancements
- **feat: Enhanced init() method** - Added optional parameters for platform-specific security configuration
- **feat: New security exceptions** - Typed exceptions for different security threats (JailbreakDetectedException, TamperingDetectedException, etc.)
- **feat: VaultSecurityConfig class** - Comprehensive configuration for security features with development/production presets
- **feat: Master encryption key deletion on clearAll()** - The `clearAll()` method now deletes the master encryption key from secure storage when `includeFiles=true` (default), providing a complete security wipe that forces key regeneration on next initialization

### Documentation Updates
- **docs: Comprehensive security features documentation** - Complete guide to using security features
- **docs: Security configuration examples** - Development, production, and custom configuration examples
- **docs: Platform-specific setup requirements** - Updated Android and iOS setup for security features
- **docs: Security best practices** - Guidelines for testing and deploying secure apps
- **docs: Certificate generation guide** - How to obtain Android signing certificate hashes
- **docs: Platform compatibility clarification** - Clear documentation that security features only work on Android and iOS

### Testing Improvements
- **test: Security configuration unit tests** - Comprehensive test suite for VaultSecurityConfig
- **test: Security exception tests** - Tests for all security-related exceptions
- **test: Threat callback testing** - Verify custom callback functionality
- **test: Platform detection testing** - Ensure security features are properly skipped on unsupported platforms

### Dependencies
- **feat: Add freerasp ^7.2.1** - Optional dependency for runtime application self-protection

### Backward Compatibility
- **No breaking changes** - Security features are completely optional
- **Graceful fallback** - Apps work exactly as before when security is not enabled
- **Optional dependency** - FreeRASP only used when security features are enabled
- **Cross-platform support** - Same code works on all platforms without modification

### 🚀 Usage Examples
#### Basic usage (no security)
    final storage = VaultStorage.create();
    await storage.init();

#### With security features
    final storage = VaultStorage.create(
      securityConfig: VaultSecurityConfig.production(
        watcherMail: 'security@mycompany.com',
        androidPackageName: 'com.mycompany.myapp',
        androidSigningCertHashes: ['your_cert_hash'],
        iosBundleId: 'com.mycompany.myapp',
        iosTeamId: 'YOUR_TEAM_ID',
      ),
    );
    // Security features will only be active on Android and iOS
    await storage.init();## [2.1.2] - 2025-08-15
### Documentation improvements
- docs: Enhanced macOS setup documentation with complete entitlement files and codesigning requirements
- docs: Added comprehensive troubleshooting steps for `StorageInitializationError` on macOS
- docs: Included detailed entitlement configurations for both DebugProfile and Release builds
- docs: Added step-by-step codesigning setup instructions in Xcode
- docs: Clarified why keychain access and codesigning are required for VaultStorage initialization

## [2.1.1] - 2025-08-11
### Web compatibility and quality
- fix: Remove `dart:isolate` from the public import graph and use `compute` from `flutter/foundation`, enabling web platform detection on pub.dev.
- fix: Use conditional imports that default to web-safe stubs and import `dart:io` only behind `dart.library.io`.
- chore: Add explicit `platforms:` section in `pubspec.yaml` to declare support for Android, iOS, Linux, macOS, Web, and Windows.
- chore: Add IO stubs in web mocks to satisfy analyzer for conditional imports.
- fix: Address analyzer warnings (avoid `await` on synchronous `containsKey`).

## [2.1.0] - 2025-08-10
### New Features
- feat: Add `clearAll({bool includeFiles = true})` to wipe both key-value and file storage in one call
- feat: Extend `clearNormal()` and `clearSecure()` with `includeFiles` (default `false`) to optionally delete underlying files and file metadata for the respective storage

### Internal
- refactor: Consolidate file-clearing logic into `clearAllFilesInBox(...)` with `@visibleForTesting` for easier testing
- test: Add coverage for `clearAll`, and `includeFiles` behavior in `clearNormal` and `clearSecure`

## [2.0.0] - 2025-08-08
This release delivers a simpler, clearer API and improved performance characteristics. It replaces the BoxType/Either-based surface with intent-driven methods and exception-based error handling. File APIs are simplified to use your own keys instead of passing metadata around.

### Breaking Changes
- API surface reworked for simplicity:
  - Removed: `set(BoxType, key, value)` and `get<T>(BoxType, key)` in favor of intent-specific methods
  - Added: `saveSecure`, `saveNormal`, `get<T>(key, {bool? isSecure})`, `delete(key)`, `clearNormal()`, `clearSecure()`
  - File retrieval unified: `getFile(key, {bool? isSecure})` (replaces passing metadata to `getSecureFile`/`getNormalFile`)
  - File deletion unified: `deleteFile(key)`
- Error handling model:
  - Removed: `Either<StorageError, T>` return style
  - Added: Methods now throw `StorageError` subclasses (`StorageInitializationError`, `StorageReadError`, `StorageWriteError`, `StorageDeleteError`, `StorageDisposalError`, `StorageSerializationError`)
- Web file retrieval
  - Custom download filenames are no longer configurable via public API; sensible filenames are generated automatically based on stored extension

### New Features
- Simplified key-value API with smart lookup order (normal first, then secure) when `isSecure` is not specified
- Secure and normal file storage keyed by your own identifiers; implementation tracks metadata internally
- Large-file encryption streaming for secure files (chunked AES-GCM) to reduce memory pressure
- Performance configuration via `VaultStorageConfig` with thresholds for JSON/base64 isolate usage and secure file streaming
- More aggressive Hive compaction strategy for better on-disk efficiency
- New: `keys({bool includeFiles = true, bool? isSecure})` API to list stored keys (unique and sorted). The example app now loads keys on startup so they persist across restarts.

### Web Platform Behavior
- Auto-downloads when calling `getFile()` on web; returns `Uint8List` and triggers browser download with a smart filename
- MIME type inference from file extension for better browser handling

### Internal Improvements
- Consistent use of isolates for heavy crypto, JSON encode/decode, and base64 encode/decode
- Clear separation of responsibilities: `IVaultStorage` (interface) and `VaultStorageImpl` (implementation), with `VaultStorage.create()` factory
- File operations abstracted behind `IFileOperations` for testability

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

## [1.2.1] - 2025-07-13
### New Features
- **feat: Automatic file downloads on web platforms** - `getSecureFile()` and `getNormalFile()` now automatically trigger downloads in web browsers while maintaining native platform behavior
- **feat: Custom download filenames** - Added optional `downloadFileName` parameter to file retrieval methods for custom web download names
- **feat: Smart filename generation** - Automatically generates appropriate filenames using stored file extensions (e.g., `document.pdf`, `image.jpg`)
- **feat: MIME type detection** - Automatic MIME type detection for 15+ common file formats ensures proper browser handling

### Technical Improvements
- **feat: Modern web standards** - Migrated from deprecated `dart:html` to modern `package:web` APIs for future WebAssembly (Wasm) compatibility
- **feat: Enhanced metadata storage** - File extensions are now stored in metadata for both secure and normal files
- **feat: Conditional imports optimization** - Updated to use `dart.library.js_interop` for better web/native platform detection

### Documentation Updates
- **docs: Enhanced README with web download examples** - Added comprehensive examples showing platform-specific behavior
- **docs: Platform behavior comparison table** - Clear documentation of differences between web and native platforms
- **docs: MIME type support documentation** - Listed all supported file types and their automatic MIME type mappings

### 🔄 Backward Compatibility
- **No breaking changes** - All existing code continues to work without modifications
- **Optional parameters** - New features use optional parameters to maintain API compatibility
- **Same return types** - Methods still return `Either<StorageError, Uint8List>` as before

### Web Platform Enhancements
- **Web downloads**: Files automatically download when retrieved on web platforms
- **Smart filenames**: Uses original file extensions for meaningful download names
- **MIME type support**: PDF, images, documents, audio, video, and more
- **Custom naming**: Optional custom filenames for downloads

### Dependencies
- **Added**: `web: ^1.1.1` for modern web API access

## [1.1.0] - 2025-07-05
### Bug Fixes
- **fix: Android compilation issues** - Fixed Android build failures by migrating from unmaintained `cryptography` package to actively maintained `cryptography_plus`
- **fix: AGP 8.x compatibility** - Resolved Android Gradle Plugin 8.x compatibility issues that prevented compilation on newer Android projects

### Dependency Updates
- **feat: Replace cryptography with cryptography\_plus** - Migrated from `cryptography: ^2.7.0` to `cryptography_plus: ^2.7.1` to ensure ongoing maintenance and Android compatibility
- **feat: Upgrade flutter\_secure\_storage** - Updated from `^9.2.4` to `^10.0.0-beta.4` for latest security improvements and bug fixes

### Migration Notes
- **Automatic migration**: No code changes required - the package handles the cryptography library migration internally
- **Android compatibility**: Projects that previously failed to compile on Android with AGP 8.x will now work correctly
- **Breaking changes**: None for end users - all public APIs remain the same

## [1.0.1] - 2025-06-27
### Documentation Improvements
- **docs: Fix incorrect parameter name in README.md** - Corrected `metadata:` to `fileMetadata:` in `getSecureFile` method example
- **docs: Fix version inconsistencies** - Updated all version references from `^0.1.1` to `^1.0.0` to match current package version
- **docs: Fix Riverpod integration example** - Corrected error handling in main.dart to use try-catch instead of incorrect `.fold()` usage
- **docs: Fix syntax errors** - Removed duplicate closing braces and fixed code formatting issues

### Technical Fixes
- **fix: Correct API usage examples** - All code examples now use the correct method signatures and parameter names
- **fix: Improve error handling patterns** - Better distinction between functional error handling (Either) and exception-based error handling (try-catch)

## [1.0.0] - 2025-06-26
### Breaking Changes
- **BREAKING: Remove built-in Riverpod provider** - The package no longer includes a built-in Riverpod provider to remain framework-agnostic
- **BREAKING: Hide implementation details** - Use `VaultStorage.create()` factory method instead
- **feat: Framework-agnostic design** - Users can now integrate with any state management solution or use the service directly

### New Features
- **feat: Add VaultStorage.create() factory method** - Clean API that returns `IVaultStorage` interface, hiding implementation details
- **feat: Improved API design** - Only the interface (`IVaultStorage`) is exposed to users, making the API cleaner and less confusing

### Documentation Improvements
- **docs: Add comprehensive state management integration examples** - Includes examples for Riverpod and direct usage
- **docs: Update initialisation examples** - Show how to initialise the service without Riverpod dependency
- **docs: Clarify framework-agnostic approach** - Emphasise that the package works with any state management solution
- **docs: Update all examples to use factory method** - Consistent API usage throughout documentation

### Migration Guide
**From built-in Riverpod provider:**
If you were using the built-in `vaultStorageProvider`, you can easily recreate it in your own project:

1. Add Riverpod dependencies to your `pubspec.yaml`
2. Create your own provider file following the examples in the README
3. Update your initialisation code to use your custom provider

**From VaultStorageImpl():**
Replace direct instantiation with the factory method:

    // Before
    final storage = VaultStorageImpl();
    
    // After
    final storage = VaultStorage.create();This change makes the package more flexible, reduces its dependency footprint, and provides a cleaner API.

## [0.1.1] - 2025-06-24
- refactor: Remove export of unused storage\_keys constant from vault\_storage.dart
- chore: Update build\_runner dependency to version 2.5.4 in pubspec.yaml
- chore: Update \_fe\_analyzer\_shared and analyzer versions in pubspec.lock
- test: Refactor error handling tests to use async/await for improved readability

## [0.1.0] - 2025-06-22
### Features
- **feat: Add support for normal file storage** - Complete implementation with save, retrieve, and delete functionalities
- **feat: Add JsonSafe utility** - Safe JSON encoding and decoding with comprehensive error handling
- **feat: Enhance storage functionality** - New task execution system with improved error handling architecture

### Core Improvements
- **feat: Add safe JSON encoding and decoding extensions** - Improved error handling for JSON operations
- **feat: Implement normal file storage** - Full file storage capabilities with proper error handling
- **feat: Improve error handling during storage initialisation** - Detailed error display and better user feedback

### Testing & Quality
- **test: Add comprehensive unit tests for VaultStorage service lifecycle** - Complete lifecycle management testing
- **test: Add TaskExecutor mock for testing** - Enhanced testing capabilities for task execution logic
- **test: Implement comprehensive StorageError class tests** - Ensures proper error handling across the package
- **test: Add tests for FileOperations and Encryption Helpers** - Validates core functionality with thorough coverage
- **test: Update VaultStorageImpl tests** - Utilise new extensions for JSON operations
- **refactor: Remove outdated test files** - Streamlined test suite by removing `vault_storage_impl_test.dart`
- **refactor: Consolidate storage keys tests** - Improved test organisation

### Documentation & Examples
- **docs: Add comprehensive use cases section** - Healthcare, financial, enterprise, and consumer app examples
- **docs: Add production use disclaimers** - Important security and legal considerations for production apps
- **docs: Add platform setup requirements** - Detailed setup instructions for all supported platforms
- **docs: Enhance troubleshooting section** - Common issues and solutions for initialisation problems
- **example: Improve error handling in example app** - Better error display and recovery mechanisms

### Security & Compliance
- **security: Add production use disclaimers** - Clear security limitations and audit requirements
- **platform: Add macOS entitlements documentation** - Required keychain access setup for macOS apps

## [0.0.4] - 2025-06-20
- refactor: Rename storageService to vaultStorage for consistency in README and tests
- chore: Update README for web compatibility and usage improvements
- docs: Clarify Riverpod dev version requirement and that generated files are included
- docs: Improve code examples and error handling documentation
- docs: Add comprehensive usage examples for both key-value and secure file storage

## [0.0.3] - 2025-06-19
- fix: Update conditional imports for web compatibility in vault\_storage\_impl.dart, from dart.library.html to dart.library.js\_interop

## [0.0.2] - 2025-06-18
- Added web compatibility for vault\_storage package.
- Enhanced storage capabilities:
  - Added secure file storage with new Hive box.
  - Updated BoxType enum to support secure file storage.
  - Implemented platform-specific file storage handling.
- Improved error handling:
  - Added disposal error handling to IVaultStorage interface.
  - Enhanced error handling throughout the package.
- Added example project with pubspec.yaml demonstrating package usage.
- Code improvements:
  - Better formatting and code consistency.
  - Cleaned up unused code in test files.
  - Refactored implementation for better maintainability.

## [0.0.1] - 2025-06-17
- Initial release of the `vault_storage` package.
- Provides secure key-value and file storage using Hive and `flutter_secure_storage`.
- Features include:
  - Dual storage model for key-value pairs and file blobs.
  - AES-GCM encryption for all sensitive data.
  - Cryptographic operations offloaded to background isolates.
  - Type-safe error handling with `fpdart`.
  - Riverpod provider for easy dependency injection.
