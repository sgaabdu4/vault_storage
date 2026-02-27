# Vault Storage

Secure, fast key-value and file storage for Flutter. Built on Hive and flutter_secure_storage with AES-GCM encryption, full web support, and background isolates for heavy crypto work.

**NEW in v4.0.0**: **Binary TypeAdapter storage** — ~30–50% faster key-value reads/writes. Each entry drops from ~36 bytes of wrapper overhead to 2 bytes. Web files stored as `Uint8List` (no base64 round-trip). Fully automatic — no code changes needed. ⚠️ Downgrade from v4.x to v3.x is not supported.

**NEW in v3.0.0**: **20-50x faster** List and Map operations via native storage. Automatic migration from v2.x, no breaking changes.

**NEW in v2.3.0**: Custom boxes for multi-tenant apps and data isolation.

**NEW in v2.2.0**: Optional FreeRASP integration — jailbreak detection and runtime security monitoring.

### Migration Benefits

Switching from the "package dance":

#### Before (Multiple Packages)
```dart
// Managing 4+ different packages with different APIs
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

// Complex initialization
await Hive.initFlutter();
final normalBox = await Hive.openBox('normal');
final secureStorage = FlutterSecureStorage();
final prefs = await SharedPreferences.getInstance();

// Different APIs for each storage type
prefs.setString('theme', 'dark');                    // SharedPreferences API
normalBox.put('cache', data);                        // Hive API  
await secureStorage.write(key: 'token', value: jwt); // Secure Storage API

// Manual file handling with encryption
final dir = await getApplicationDocumentsDirectory();
final file = File('${dir.path}/encrypted_file.dat');
// ...custom encryption logic...
```

#### After (Vault Storage)
```dart
import 'package:vault_storage/vault_storage.dart';

// Single initialization
final storage = VaultStorage.create();
await storage.init();

// Unified API for all storage needs
await storage.saveNormal(key: 'theme', value: 'dark');
await storage.saveNormal(key: 'cache', value: data);
await storage.saveSecure(key: 'token', value: jwt);
await storage.saveSecureFile(
  key: 'document',
  fileBytes: bytes,
  originalFileName: 'file.pdf',
);
```

#### Results
- **90% less boilerplate code**
- **Single API to learn and maintain** 
- **Built-in encryption** - no manual crypto implementation
- **Consistent error handling** across all storage types
- **Web compatibility** without extra platform logic

## Table of Contents

- [Features](#features)
- [Use Cases](#use-cases)
- [Why Choose Vault Storage?](#why-choose-vault-storage)
- [Security Features (NEW!)](#security-features-new)
- [Important Notes for Production Use](#important-notes-for-production-use)
- [Compliance & Standards](#compliance--standards)
- [Getting Started](#getting-started)
- [Migration Guide: 1.x -> 2.0](#migration-guide-1x---20)
- [Quick Start](#quick-start)
- [Platform Setup](#platform-setup)
- [Usage](#usage)
- [Performance Tuning](#performance-tuning)
- [Error Handling](#error-handling)
- [Troubleshooting](#troubleshooting)
- [Platform Support](#platform-support)

## Features

- **Simple API**: Clear-intent methods (`saveSecure`/`saveNormal`/`get`/`delete`/`clear`)
- **Smart lookups**: `get()` checks normal first, then secure; constrain via `isSecure`
- **List stored keys**: `keys()` returns stored keys (filter by secure/normal, include file keys)
- **Encrypted file storage**: AES-GCM 256-bit and normal file storage, unified API across platforms
- **Jailbreak protection**: Optional FreeRASP integration for runtime security
- **Threat detection**: Detect rooting, debugging, and app tampering
- **Web compatible**: Native file system on devices; web stores bytes in Hive with auto-download
- **Fast by default**: Crypto, JSON, and base64 offloaded to isolates for large payloads
- **Large-file streaming**: Chunked encryption reduces memory pressure for big files
- **Configurable performance**: Adjust isolate thresholds via `VaultStorageConfig`
- **Framework agnostic**: Works with any state management or none

## Use Cases

### Healthcare & Medical Apps
- **Patient Records**: Store medical data with HIPAA-grade encryption
- **Medical Imaging**: Save diagnostic images offline with encryption
- **Health Tracking**: Encrypt sensitive health data at rest

### Financial & Banking Apps
- **Auth Tokens**: Store JWT tokens and API keys securely
- **Transaction Data**: Encrypt financial records (PCI DSS compliant)
- **Biometric Data**: Protect fingerprint and face ID templates
- **Digital Wallets**: Secure cryptocurrency keys and payment info

### Enterprise & Business Apps
- **Corporate Docs**: Encrypt contracts and confidential documents
- **Employee Data**: Encrypt credentials and personal info
- **API Keys**: Encrypt third-party service credentials
- **Audit Trails**: Maintain encrypted logs for compliance
- **Tamper Protection**: Detect modified apps or compromised environments

### Consumer Apps with Real Users
- **Password Managers**: Store encrypted passwords and secure notes
- **Messaging Apps**: Cache encrypted messages and media files
- **Personal Vaults**: Encrypt IDs, certificates, and personal documents
- **Social Apps**: Protect user data and private content
- **Device Security**: Block access on jailbroken/rooted devices

### Cross-Platform Apps
- **Consistent Security**: Same protection across mobile, web, and desktop
- **Large Files**: Handle large encrypted files (images, videos, documents)
- **Offline-First**: Secure local storage that works without internet

### Why Choose Vault Storage?

One package replaces several, with encryption built in.

#### Built for Real-World Applications
- **Security by Default**: AES-256-GCM encryption for all secure data, no manual setup
- **Runtime Protection**: Optional jailbreak detection and app integrity monitoring
- **Performance First**: Crypto and JSON work runs in background isolates; the UI thread stays free
- **True Cross-Platform**: One API across mobile, web, and desktop
- **Clear Error Handling**: Typed `VaultStorageError` subtypes for every failure mode

#### Future-Proof Your App
- **Scalable**: Start with key-value storage, add encrypted files later — same API
- **Compliance Ready**: Covers GDPR, HIPAA, and PCI DSS data-at-rest requirements
- **Production Ready**: Used in production apps handling sensitive user data
- **Pragmatic**: Simple API, tested internals

#### Developer Experience
- **Clean API**: Methods that handle security internally
- **Batteries Included**: Error types, utilities, and full documentation
- **Well Tested**: 97.5% test coverage
- **Complete Documentation**: Examples, use cases, and troubleshooting guides

#### Perfect for Both Simple and Complex Apps

**Growing app?** Start with preferences, add file encryption later — same API.

**Enterprise app?** Security and compliance without the complexity.

**Consumer app?** Protect user data without compromising performance.

> **Pro Tip**: Even if you store only preferences today, secure storage from day one prevents costly migrations when you add accounts, premium features, or sensitive data.

## Security Features (NEW!)

Optional runtime security monitoring via [FreeRASP](https://freerasp.talsec.app/). Detects jailbreaks, tampering, hooking, and more on Android and iOS.

**Platform Support**: Security features run **only on Android and iOS**. Other platforms ignore the configuration and work normally.

### What's Protected

- **Jailbreak/Root Detection**: Block access on compromised devices
- **App Tampering**: Detect modified or repackaged apps  
- **Debug Detection**: Prevent debugging in production builds
- **Hook Detection**: Detect runtime manipulation (Frida, Xposed, etc.)
- **Emulator Detection**: Detect emulators and simulators
- **Unofficial Store**: Detect installation from unofficial app stores
- **Screen Capture**: Monitor screenshots and screen recording
- **System VPN**: Detect system VPN usage
- **Device Security**: Check for device passcode and secure hardware

### Quick Start with Security

```dart
import 'package:vault_storage/vault_storage.dart';

// Create storage with security enabled (Android/iOS only)
final storage = VaultStorage.create(
  securityConfig: VaultSecurityConfig.production(
    watcherMail: 'security@mycompany.com',
    androidPackageName: 'com.mycompany.myapp',
    androidSigningCertHashes: ['your_cert_hash'],
    iosBundleId: 'com.mycompany.myapp',
    iosTeamId: 'YOUR_TEAM_ID',
    threatCallbacks: {
      SecurityThreat.jailbreak: () {
        // Custom handling - log event, show warning, etc.
        print('Warning: Jailbreak detected - limiting functionality');
      },
      SecurityThreat.tampering: () {
        // Handle app tampering - could exit app
        print('Alert: App integrity compromised');
        exit(0);
      },
    },
  ),
);

// Initialize storage
// Note: Security features only work on Android and iOS
await storage.init();

// Use normally - security runs automatically in background
await storage.saveSecure(key: 'api_key', value: 'secret');
```

### Security Configuration Options

#### Development Mode

```dart
final devConfig = VaultSecurityConfig.development(
  watcherMail: 'dev@mycompany.com',
  threatCallbacks: {
    SecurityThreat.jailbreak: () => print('Jailbreak detected in dev'),
  },
);
// - Blocks nothing by default
// - Logs all threats
// - Allows debugging and emulators
// - Only works on Android and iOS
```

#### Production Mode

```dart
final prodConfig = VaultSecurityConfig.production(
  watcherMail: 'security@mycompany.com',
  threatCallbacks: {
    SecurityThreat.jailbreak: () => showSecurityWarning(),
    SecurityThreat.tampering: () => exit(0),
  },
);
// - Blocks jailbreak, tampering, unofficial stores
// - Minimal logging
// - Strict security posture
// - Only works on Android and iOS
```

#### Custom Configuration

```dart
final customConfig = VaultSecurityConfig(
  enableRaspProtection: true,
  isProd: true,
  watcherMail: 'security@mycompany.com',
  
  // Granular control over blocking
  blockOnJailbreak: true,
  blockOnTampering: true,
  blockOnHooks: true,
  blockOnDebug: false,          // Allow debugging
  blockOnEmulator: false,       // Allow emulators for testing
  blockOnUnofficialStore: true,
  
  enableLogging: true,
  threatCallbacks: {
    SecurityThreat.jailbreak: () => handleJailbreak(),
    SecurityThreat.tampering: () => handleTampering(),
    SecurityThreat.screenshot: () => logScreenCapture(),
    // ... handle other threats as needed
  },
);
// Note: Only effective on Android and iOS platforms
```

### Security Error Handling

When a blocked threat is detected:

```dart
try {
  await storage.saveSecure(key: 'sensitive_data', value: data);
} on JailbreakDetectedException {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Text('Security Warning'),
      content: Text('This device appears to be jailbroken. Some features may be limited.'),
    ),
  );
} on TamperingDetectedException {
  // App has been modified - consider exiting
  exit(0);
} on SecurityThreatException catch (e) {
  print('Security threat detected: ${e.threatType} - ${e.message}');
}
```

### Getting Your App Certificates

Get your signing certificate hash (Base64):

```bash
# For debug builds
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android

# For release builds  
keytool -list -v -keystore your-release-key.keystore -alias your-key-alias

# Look for SHA256 fingerprint, convert to Base64
```

For iOS, get your Team ID from Apple Developer Console.

### Security Monitoring Dashboard

FreeRASP provides a free monitoring dashboard:
- View security events from your apps
- Compare threat levels to global averages  
- Track security trends over time
- Export security reports

Register at [https://freerasp.talsec.app/](https://freerasp.talsec.app/) using the same email as `watcherMail`.

### Without Security Features

Security is optional. Without a `securityConfig`, storage works as before:

```dart
// No security features - works on all platforms
final storage = VaultStorage.create();
await storage.init();
```

**Cross-Platform Compatibility**: Security config is safe to include on all platforms:
- **Android & iOS**: Full security monitoring and threat detection
- **macOS, Windows, Linux, Web**: Normal vault storage without security features

One codebase, all platforms — no conditional logic needed.

## Important Notes for Production Use

> **Security Disclaimer**: Vault Storage uses AES-GCM 256-bit encryption and follows security best practices, but **no software guarantees absolute security**. Conduct your own security audits before deploying to production with sensitive data.

### Security Considerations
- **Audit Required**: Audit independently before handling sensitive data
- **Compliance**: Verify your implementation meets your regulatory requirements
- **Key Management**: Secure storage quality varies by platform
- **Testing**: Test encryption/decryption in your specific use case
- **RASP Limitations**: FreeRASP adds runtime protection, but no security layer is infallible
- **False Positives**: Security features may trigger false positives — test in your environment

### Legal & Compliance
- **Your Responsibility**: Ensure compliance with applicable laws and regulations
- **Data Protection**: Review data protection requirements for your jurisdiction and industry
- **User Consent**: Obtain user consent for data collection and storage
- **Backup Strategy**: Plan for backup and recovery

### Best Practices
- **Regular Updates**: Keep the package and dependencies updated for security patches
- **Error Handling**: Handle storage failures explicitly
- **Data Minimisation**: Store only what you need
- **Access Control**: Add access controls at the application layer
- **Security Testing**: Test behavior when threats are detected
- **Graceful Degradation**: Handle security blocks gracefully

> **Recommendation**: For mission-critical applications, add certificate pinning, RASP, and regular penetration testing.

## Compliance & Standards

Vault Storage helps meet common regulatory requirements:

### Healthcare (HIPAA)
- **AES-256-GCM encryption** for all sensitive data
- **Platform keychain storage** for encryption keys
- **Secure file handling** for medical documents and images
- **Access logging** capabilities for audit trails
- **Data minimization** through selective encryption

### Financial (PCI DSS)
- **Strong cryptography** for payment data protection
- **Secure key management** using platform secure storage
- **File encryption** for financial documents
- **Runtime security monitoring** (Android/iOS) to detect tampering

### Enterprise (SOC 2)
- **Data encryption at rest** for sensitive corporate data
- **Access controls** through app-level implementation
- **Security monitoring** with FreeRASP integration
- **Error logging** for security event tracking

### GDPR Compliance
- **Data encryption** to protect personal information
- **Right to deletion** through clear storage management
- **Data portability** through standardized export/import
- **Minimal data collection** - no analytics or telemetry

> **Important**: Vault Storage provides security foundations; you are responsible for full regulatory compliance. Audit before deploying to production.

## Getting Started

Add to your `pubspec.yaml`:

```yaml
dependencies:
  # ... other dependencies
  vault_storage: ^4.0.0 # Replace with the latest version
```

Then run:
```bash
flutter pub get
```

## Migration Guide: 1.x -> 2.0

This release drops `BoxType` and `Either`, simplifying the API surface.

### Why this change?

- **Clarity and intent**: `saveSecure`, `saveNormal`, and `get(..., isSecure)` name intent explicitly and reduce misuse
- **Simpler error handling**: Typed `VaultStorageError` exceptions replace `Either`-based handling scattered across call sites
- **Less leakage of internals**: Dropping `BoxType` decouples callers from storage internals
- **Web and files ergonomics**: A key-based file API (with web auto-download) replaces metadata maps
- **Performance and maintainability**: A smaller surface simplifies internal optimization and future changes

**Trade-offs** (considered acceptable):
- Exceptions require `try/catch` instead of `.fold()` patterns
- Web downloads use a default filename rather than app-controlled names in this API

1) Initialisation and errors
- Before: `await storage.init()` returned `Either`, handled via `.fold()`
- After: `await storage.init()` throws on failure. Use try/catch.

2) Key-value API
- Before:
  - `await storage.set(BoxType.secure, 'k', 'v')`
  - `final v = await storage.get<String>(BoxType.secure, 'k')`
- After:
  - `await storage.saveSecure(key: 'k', value: 'v')`
  - `final v = await storage.get<String>('k', isSecure: true)`
  - Normal data: `saveNormal(...)` and `get(..., isSecure: false)`
  - Delete: `await storage.delete('k')` (removes from both storages)
  - Clear: `await storage.clearNormal()`, `await storage.clearSecure()`

3) File storage
- Before:
  - `saveSecureFile(fileBytes, fileExtension)` returned metadata Map you stored and later passed to `getSecureFile(metadata, downloadFileName: ...)`
- After:
  - `await saveSecureFile(key: 'profile', fileBytes: bytes, originalFileName: 'x.jpg', metadata: {...})`
  - Retrieve with `await getFile('profile')` (auto-detect secure/normal); optionally constrain via `isSecure`
  - Delete with `await deleteFile('profile')`
  - Web: files auto-download on `getFile()`; custom filenames are not configurable in this API

4) Error handling
- Before: `Either<StorageError, T>` results
- After: methods throw `VaultStorageError` subclasses (`VaultStorageReadError`, `VaultStorageWriteError`, etc.)

5) Performance & internals
- Large JSON/base64 handled via isolates; thresholds configurable in `VaultStorageConfig`
- Large secure files use streaming encryption
- More aggressive Hive compaction

See CHANGELOG for full details.

## Quick Start

Use the factory to create an instance and initialise at app start:

```dart
import 'package:vault_storage/vault_storage.dart';

final storage = VaultStorage.create();
await storage.init();

// Save values
await storage.saveSecure(key: 'api_key', value: 'my_secret_key');
await storage.saveNormal(key: 'theme', value: 'dark');

// Read values (normal first, then secure)
final token = await storage.get<String>('api_key');
final theme = await storage.get<String>('theme');

// Constrain lookup to secure or normal storage
final secureOnly = await storage.get<String>('api_key', isSecure: true);
final normalOnly = await storage.get<String>('theme', isSecure: false);
```

The factory returns `IVaultStorage`, hiding implementation details.

### Custom Boxes (NEW in v2.3.0)

Create isolated storage boxes for multi-tenancy or feature separation:

```dart
import 'package:vault_storage/vault_storage.dart';

// Create storage with custom boxes
final storage = VaultStorage.create(
  customBoxes: [
    BoxConfig(name: 'user_123', encrypted: true),
    BoxConfig(name: 'workspace_abc', encrypted: true),
    BoxConfig(name: 'cache', encrypted: false),
  ],
);

// Initialize storage
await storage.init();

// Use specific boxes
await storage.saveSecure(
  key: 'api_key',
  value: 'secret',
  box: 'user_123', // Store in custom box
);

// Read from specific box
final value = await storage.get<String>(
  'api_key',
  box: 'user_123',
);

// Each box is completely isolated
await storage.saveNormal(
  key: 'preferences',
  value: {'theme': 'dark'},
  box: 'workspace_abc',
);
```

**Custom box uses:**
- **Multi-tenant apps**: Separate storage per user or organization
- **Feature isolation**: Independent storage for different app modules
- **Data lifecycle**: Separate boxes for cache vs. persistent data
- **Workspace management**: Multiple workspaces with isolated data

## Platform Setup

This package uses `flutter_secure_storage` for key management, which needs platform-specific setup:

### Android

In `android/app/build.gradle`, set minimum SDK to 23+ for security features (18+ for basic storage):

```gradle
android {
    defaultConfig {
        minSdkVersion 23  // Required for FreeRASP security features
        // minSdkVersion 18  // Minimum for basic storage without security
    }
}
```

#### Security Features (FreeRASP) - Additional Setup

Add to `android/src/main/AndroidManifest.xml`:

```xml
<!-- For screenshot and screen recording detection (optional) -->
<uses-permission android:name="android.permission.DETECT_SCREEN_CAPTURE" />
<uses-permission android:name="android.permission.DETECT_SCREEN_RECORDING" />
```

In `android/settings.gradle`:

```gradle
plugins {
    id "dev.flutter.flutter-plugin-loader" version "1.0.0"
    id "com.android.application" version "8.8.1" apply false
    id "org.jetbrains.kotlin.android" version "2.1.0" apply false
}
```

**Note**: To prevent backup-related keystore issues, disable auto-backup in `AndroidManifest.xml`:

```xml
<application
    android:allowBackup="false"
    android:fullBackupContent="false"
    android:dataExtractionRules="@xml/data_extraction_rules"
    ...>
```

### iOS

No additional setup needed for basic storage. The package uses iOS Keychain.

#### Security Features (FreeRASP) - Additional Setup

For apps using security features, ensure Xcode 15+ is installed.

### macOS

**Required**: Add Keychain entitlements and configure codesigning to prevent `VaultStorageInitializationError`.

#### 1. Create or update entitlement files

**`macos/Runner/DebugProfile.entitlements`:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.cs.allow-jit</key>
    <true/>
    <key>com.apple.security.network.server</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
    <key>com.apple.security.files.downloads.read-write</key>
    <true/>
    <key>keychain-access-groups</key>
    <array>
        <string>$(AppIdentifierPrefix)$(CFBundleIdentifier)</string>
    </array>
</dict>
</plist>
```

**`macos/Runner/Release.entitlements`:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
    <key>com.apple.security.files.downloads.read-write</key>
    <true/>
    <key>keychain-access-groups</key>
    <array>
        <string>$(AppIdentifierPrefix)$(CFBundleIdentifier)</string>
    </array>
</dict>
</plist>
```

#### 2. Configure Codesigning

1. Open `macos/Runner.xcworkspace` in Xcode
2. Select the Runner project in the navigator
3. Go to "Signing & Capabilities" tab
4. Ensure:
   - **Team** is selected (required for keychain access)
   - **Bundle Identifier** matches your app's identifier
   - **Signing Certificate** is valid
   - **Keychain Sharing** capability is added (appears with the entitlements)

#### 3. Clean and rebuild after setup

```bash
flutter clean
flutter pub get
flutter run -d macos
```

#### 4. Troubleshooting macOS Issues

If `VaultStorageInitializationError` persists:

1. **Check Console app** for detailed error messages from your app
2. **Verify codesigning**: `codesign -dv --verbose=4 /path/to/your/app.app`
3. **Reset Keychain** (development only): Delete your app's keychain entries if corrupted
4. **Check entitlements**: `codesign -d --entitlements - /path/to/your/app.app`

**Why this is required**: VaultStorage stores encryption keys in macOS Keychain. Without entitlements and codesigning, the system blocks Keychain access and throws `VaultStorageInitializationError`.

### Linux

Install required system dependencies:

```bash
sudo apt-get install libsecret-1-dev libjsoncpp-dev
```

For runtime: `libsecret-1-0` and `libjsoncpp1`

### Windows

No additional setup needed.

**How Secure Storage Works on Windows:**
- Windows uses **DPAPI (Data Protection API)** to encrypt the master encryption key (via `flutter_secure_storage`)
- The encrypted key is stored in a file at: `%APPDATA%\<app_name>\flutter_secure_storage.dat`
- Your data is encrypted with AES-256-GCM in Hive boxes on disk
- DPAPI ties encryption to your Windows user account, blocking other users and machines
- DPAPI storage outperforms Windows Credential Manager and scales to large apps
- The key file (`hive_encryption_key`) is stored inside the encrypted `.dat` file, not in Windows Credential Manager

**Note:** `readAll` and `deleteAll` operations have limitations on Windows due to `flutter_secure_storage` constraints.

**Debug: Finding the encrypted file on Windows:**

To find the encryption key file, use the example app:

1. Run the example app: `cd example && flutter run -d windows`
2. Click the "🔍 Show Storage Location" button
3. The dialog will show you the exact path, typically:
   - `C:\Users\<username>\AppData\Roaming\<app_name>\flutter_secure_storage.dat`

You can also programmatically get this path using `path_provider`:
```dart
import 'package:path_provider/path_provider.dart';
import 'dart:io';

final appSupportDir = await getApplicationSupportDirectory();
final encryptedKeyFile = File('${appSupportDir.path}${Platform.pathSeparator}flutter_secure_storage.dat');
print('Encrypted key location: ${encryptedKeyFile.path}');
print('File exists: ${await encryptedKeyFile.exists()}');
```

### Web

The package uses WebCrypto on web:

- Use HTTPS in production; consider adding Strict-Transport-Security headers
- Data is browser/domain specific and non-portable
- Auto-downloads on file retrieval

Recommended header:
```
Strict-Transport-Security: max-age=31536000; includeSubDomains
```

Before running your app, initialise the service in `main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:vault_storage/vault_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise the vault storage
  final storage = VaultStorage.create();
  try {
    await storage.init();
    runApp(MyApp(storage: storage));
  } on VaultStorageError catch (e) {
    // Handle initialisation error appropriately
    debugPrint('Failed to initialise storage: ${e.message}');
    runApp(const ErrorApp());
  }
}

class MyApp extends StatelessWidget {
  final IVaultStorage storage;
  
  const MyApp({super.key, required this.storage});
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My App',
      home: MyHomePage(storage: storage),
    );
  }
}
```

## Usage

### Framework-Agnostic Design

**Important**: Vault Storage has no state management dependency. It works with:
- **No framework**: Direct instantiation and usage
- **Riverpod**: Integration examples below
- **Bloc**: Works with any Bloc pattern
- **Provider**: Works with Provider  
- **GetX**: Works with GetX
- **Any other solution**: Use whatever suits your project

### Basic Usage (No Dependencies)

Use Vault Storage without any state management:

```dart
import 'package:vault_storage/vault_storage.dart';

class StorageManager {
  static IVaultStorage? _instance;

  static Future<IVaultStorage> get instance async {
    if (_instance != null) return _instance!;
    final s = VaultStorage.create();
    await s.init();
    return _instance = s;
  }
}

// Usage example
Future<void> example() async {
  final storage = await StorageManager.instance;

  await storage.saveSecure(key: 'api_key', value: 'my_secret_key');
  final value = await storage.get<String>('api_key', isSecure: true);
  debugPrint('Retrieved API key: $value');
}
```

### Using with Riverpod

If you use Riverpod, create a provider:

```yaml
dependencies:
  vault_storage: ^2.0.0
  flutter_riverpod: ^2.5.0
  riverpod_annotation: ^2.3.3

dev_dependencies:
  build_runner: ^2.4.7
  riverpod_generator: ^2.3.9
```

Create your provider file: `lib/providers/storage_provider.dart`

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vault_storage/vault_storage.dart';

part 'storage_provider.g.dart';

@Riverpod(keepAlive: true)
Future<IVaultStorage> vaultStorage(VaultStorageRef ref) async {
  final implementation = VaultStorage.create();
  await implementation.init();
  ref.onDispose(() async => implementation.dispose());
  return implementation;
}
```

Run code generation:
```bash
dart run build_runner build
```

Use in your widgets:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/storage_provider.dart';

class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(vaultStorageProvider).when(
      data: (storage) => YourWidget(storage: storage),
      loading: () => CircularProgressIndicator(),
      error: (error, stack) => Text('Error: $error'),
    );
  }
}
```

Update your main.dart:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/storage_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final container = ProviderContainer();
  try {
    await container.read(vaultStorageProvider.future);
    runApp(
      UncontrolledProviderScope(
        container: container,
        child: const MyApp(),
      ),
    );
  } catch (error) {
    runApp(const ErrorApp());
  }
}
```

### Key-Value Storage

Store and retrieve key-value pairs:

```dart
// Secure data (encrypted)
await storage.saveSecure(key: 'user_token', value: 'jwt_token_here');
await storage.saveSecure(key: 'user_credentials', value: {
  'username': 'john_doe',
  'password': 'hashed_password',
});

// Normal data (faster, unencrypted)
await storage.saveNormal(key: 'theme_mode', value: 'dark');
await storage.saveNormal(key: 'language', value: 'en');

// Retrieve data
final token = await storage.get<String>('user_token', isSecure: true);
final theme = await storage.get<String>('theme_mode', isSecure: false);
```

### File Storage (Secure and Normal)

For images, documents, or binary data:

```dart
import 'dart:typed_data';

Future<void> handleFileStorage(IVaultStorage storage) async {
  final Uint8List imageData = /* from picker/network */ Uint8List(0);

  // Save a secure file (encrypted)
  await storage.saveSecureFile(
    key: 'profile_image',
    fileBytes: imageData,
    originalFileName: 'avatar.jpg',
    metadata: {'userId': '123'}, // optional user metadata
  );

  // Save a normal file (unencrypted)
  await storage.saveNormalFile(
    key: 'cached_document',
    fileBytes: imageData,
    originalFileName: 'document.pdf',
  );

  // Retrieve file bytes by key
  final secureBytes = await storage.getFile('profile_image'); // web auto-downloads
  final normalBytes = await storage.getFile('cached_document', isSecure: false);

  // Delete files
  await storage.deleteFile('profile_image');
  await storage.deleteFile('cached_document');
}
```

Note on web: `getFile()` auto-downloads using a filename derived from the stored extension. This API does not support custom download filenames.

### Storage Classes Under the Hood

Internally, Vault Storage keeps separate boxes for normal/secure key-value data and normal/secure files. The public API abstracts this; you provide keys and an optional `isSecure` flag.

### Platform-Specific Behaviour

The package handles platform differences automatically:

#### File Retrieval

- Web: Auto-downloads file, returns Uint8List
- Native: Returns Uint8List (no download)

#### File Storage

- **Native platforms** (iOS, Android, macOS, Windows, Linux): Files stored in the app's documents directory
- **Web**: Encrypted and normal file bytes stored as `Uint8List` directly in Hive boxes (browser storage). Legacy base64 data from v3.x is read automatically.

#### Automatic MIME Type Detection (Web)

For web downloads, MIME types are inferred from file extensions (PDF, images, docs, audio/video, archives, JSON/TXT, etc.). Unknown types default to `application/octet-stream`.

No code changes needed.

### Initialisation in main()

```dart
import 'package:flutter/material.dart';
import 'package:vault_storage/vault_storage.dart';

late final IVaultStorage vaultStorage;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise storage
  vaultStorage = VaultStorage.create();
  await vaultStorage.init();
  debugPrint('Storage initialised successfully');

  runApp(const MyApp());
}

// Use the service anywhere in your app
Future<void> useStorage() async {
  await vaultStorage.saveSecure(key: 'api_key', value: 'my_secret_key');
}
```

## Error Handling

All methods throw typed `VaultStorageError` subclasses:

```dart
try {
  await vaultStorage.saveSecure(key: 'k', value: 'v');
  final v = await vaultStorage.get<String>('k', isSecure: true);
} on VaultStorageInitializationError catch (e) {
  debugPrint('Storage not initialised: ${e.message}');
} on VaultStorageReadError catch (e) {
  debugPrint('Read failed: ${e.message}');
} on VaultStorageWriteError catch (e) {
  debugPrint('Write failed: ${e.message}');
} on VaultStorageSerializationError catch (e) {
  debugPrint('Serialization failed: ${e.message}');
}
```

## Storage Management

```dart
// Delete a key from both storages
await vaultStorage.delete('api_key');

// Clear storages
await vaultStorage.clearNormal();
await vaultStorage.clearSecure();

// Inspect keys
final keys = await vaultStorage.keys(includeFiles: true);

// Dispose (e.g., on shutdown)
await vaultStorage.dispose();
```

## Performance Tuning

### V4.0 Performance Improvements

V4.0 uses a custom Hive TypeAdapter for internal storage metadata:

**What changed:**
- Per-entry overhead: ~36 bytes (old Map wrapper) → 2 bytes (TypeAdapter)
- One fewer Map allocation and two fewer string lookups on every read/write
- File metadata stored as binary — no JSON encode/decode round-trip
- Web file bytes stored as `Uint8List` directly — no base64 encode/decode per file save/read
- WASM int warning from hive_ce v2.9.0 eliminated

**Migration:**
- ✅ Fully automatic — v2.x and v3.x data still read correctly
- ⚠️ Cannot downgrade to v3.x after writing new entries

### V3.0 Performance Improvements

V3.0 reads Lists and Maps **20-50x faster**:

**Performance Gains:**
- 40-item list: 1000ms → 20ms read time (50x faster)
- 100-item list: 2500ms → 50ms read time (50x faster)
- **Automatic optimization** - no code changes needed

**Migration:**
- ✅ Fully automatic - existing code works as-is
- ✅ Backward compatible - reads v2.x data without issues
- ⚠️ Cannot downgrade to v2.x after upgrade (v3.x). Cannot downgrade to v3.x after v4.x upgrade.

### Configurable Thresholds

Defaults suit most workloads. Override if needed:

```dart
// Optional: customize performance thresholds at startup
VaultStorageConfig.jsonIsolateThreshold = 15000; // chars
VaultStorageConfig.base64IsolateThreshold = 100000; // bytes  
VaultStorageConfig.secureFileStreamingThresholdBytes = 1 * 1024 * 1024; // 1MB
```

### Background Processing

Background isolates handle heavy operations:
- **JSON serialization/deserialization**: For objects larger than the threshold
- **Base64 encoding/decoding**: For files larger than the threshold  
- **Encryption/decryption**: All secure operations run in the background
- **File I/O**: Large files are streamed to prevent memory spikes

The UI thread stays responsive during large operations.

### Benchmarks

Compared with managing multiple packages separately:
- **Initialization**: 2-3x faster setup with single `init()` call
- **Memory usage**: 40% less memory overhead with unified storage
- **Bundle size**: Eliminates 3-4 separate dependencies
- **Error handling**: 80% reduction in error-handling code

## Troubleshooting

### Common Initialisation Errors

#### "Failed to create/decode secure key"

This happens when `flutter_secure_storage` cannot access the platform's secure storage:

**macOS**: Ensure keychain entitlements are configured (see Platform Setup above)

**Android**: Check that minSdkVersion >= 18 and consider disabling auto-backup

**Solution**: Verify platform setup and restart after changes

#### App Crashes on First Launch

If the app crashes during storage initialisation:

1. Check that all platform requirements are met
2. Ensure proper error handling in your `main()` function:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final storage = VaultStorage.create();
  try {
    await storage.init();
    runApp(MyApp(storage: storage));
  } on VaultStorageError catch (e) {
    debugPrint('Storage initialisation failed: ${e.message}');
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('Storage initialisation failed: ${e.message}'),
        ),
      ),
    ));
  }
}
```

#### Web Storage Issues

For web applications:
- Ensure HTTPS is enabled for production
- Check browser compatibility with WebCrypto
- Verify that local storage is enabled

### Debug Mode

On failure, check console output — the package logs detailed error messages.

## Testing

To run tests:

```bash
flutter test
```

## Dependencies

- **`hive_ce_flutter`**: Local storage database
- **`flutter_secure_storage`**: Secure key storage
- **`cryptography_plus`**: AES-GCM encryption
- **`web`**: Modern web APIs for web downloads
- **`freerasp`**: Optional runtime security monitoring and jailbreak detection (Android/iOS only)

## Platform Support

- **Android**
- **iOS**  
- **Web**
- **macOS**
- **Windows**
- **Linux**

## License

This project is licensed under the MIT License.

---