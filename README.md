# Vault Storage

Secure, fast key-value and file storage for Flutter. Built on Hive and flutter_secure_storage with AES-GCM encryption, full web support, and background isolates for heavy crypto work.

**v4.0.0**: Binary TypeAdapter storage — each entry drops from ~36 bytes of wrapper overhead to 2 bytes, yielding ~30-50% faster key-value reads/writes. Web files stored as `Uint8List` (no base64 round-trip). Fully automatic — no code changes needed. Downgrade from v4.x to v3.x is not supported.

**v3.0.0**: 20-50x faster List and Map operations via native storage. Automatic migration from v2.x, no breaking changes.

**v2.3.0**: Custom boxes for multi-tenant apps and data isolation.

**v2.2.0**: Optional FreeRASP integration — jailbreak detection and runtime security monitoring.

### Migration Benefits

One package replaces the multi-package dance:

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

One API replaces four packages. Encryption is built in. Error handling is consistent across all storage types, and web works without extra platform logic.

## Table of Contents

- [Features](#features)
- [Use Cases](#use-cases)
- [Security Features](#security-features)
- [Production Notes](#production-notes)
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

- **Clear-intent API**: `saveSecure`, `saveNormal`, `get`, `delete`, `clear` — plus `keys()` to list stored keys by type
- **Smart lookups**: `get()` checks normal first, then secure; constrain with `isSecure` or `box`
- **AES-GCM 256-bit file encryption** and normal file storage, unified API across all platforms
- **Optional runtime security**: FreeRASP integration detects jailbreaks, rooting, debugging, and tampering (Android/iOS)
- **Web compatible**: Native file system on devices; web stores bytes in Hive with auto-download on retrieval
- **Background processing**: Crypto, JSON, and base64 offloaded to isolates for large payloads; chunked encryption for big files
- **Configurable thresholds**: Tune isolate cutoffs via `VaultStorageConfig`
- **Custom boxes**: Isolated storage per tenant, feature, or data lifecycle (v2.3.0+)
- **Typed errors**: `VaultStorageError` subclasses for every failure mode
- **97.5% test coverage**

Works with any state management solution or none.

## Use Cases

Vault Storage fits any app that stores sensitive data locally. Healthcare apps can encrypt patient records and medical images at rest. Financial apps can protect auth tokens, transaction records, and payment credentials. Enterprise apps can isolate per-tenant data, encrypt API keys, and maintain audit trails with tamper detection.

Consumer apps benefit too: password managers, messaging apps caching encrypted media, and personal vaults for IDs and certificates. On Android and iOS, FreeRASP blocks access on jailbroken or rooted devices.

The same API works across mobile, web, and desktop. Files of any size stream through chunked encryption without blocking the UI. Offline-first architectures get local encryption with no server dependency.

## Security Features

Optional runtime security monitoring via [FreeRASP](https://freerasp.talsec.app/). Detects jailbreaks, tampering, hooking, and more on Android and iOS. Other platforms ignore the configuration and work normally.

### What's Protected

- Jailbreak/root detection
- App tampering and repackaging
- Debug detection in production builds
- Runtime manipulation (Frida, Xposed, etc.)
- Emulator and simulator detection
- Unofficial store installation
- Screen capture monitoring
- System VPN detection
- Device passcode and secure hardware checks

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

FreeRASP provides a free monitoring dashboard at [https://freerasp.talsec.app/](https://freerasp.talsec.app/). Register with the same email as `watcherMail` to view security events, compare threat levels, and export reports.

### Without Security Features

Security is optional. Without a `securityConfig`, storage works on all platforms with no security overhead:

```dart
final storage = VaultStorage.create();
await storage.init();
```

Security config is safe to include on all platforms. Android and iOS get full monitoring; macOS, Windows, Linux, and web operate normally without it. One codebase, no conditional logic.

## Production Notes

Vault Storage uses AES-GCM 256-bit encryption and follows security best practices, but no software guarantees absolute security. Audit independently before deploying with sensitive data.

- Verify your implementation meets your regulatory requirements (GDPR, HIPAA, PCI DSS, etc.)
- Secure storage quality varies by platform — test encryption and decryption in your target environment
- FreeRASP adds runtime protection but may produce false positives; test in your environment
- Store only what you need and add access controls at the application layer
- Handle storage failures explicitly and plan for backup and recovery
- Keep the package and dependencies updated for security patches
- Obtain required user consent for data collection and storage

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

- `saveSecure`, `saveNormal`, and `get(..., isSecure)` name intent explicitly and reduce misuse
- Typed `VaultStorageError` exceptions replace `Either`-based handling
- Dropping `BoxType` decouples callers from storage internals
- A key-based file API (with web auto-download) replaces metadata maps
- A smaller surface simplifies internal optimization and future changes

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

5) Performance and internals
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

### Custom Boxes (v2.3.0+)

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

Custom boxes suit multi-tenant apps (separate storage per user or organization), feature isolation, cache vs. persistent data separation, and workspace management.

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

To prevent backup-related keystore issues, disable auto-backup in `AndroidManifest.xml`:

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

Add Keychain entitlements and configure codesigning. Without these, `VaultStorageInitializationError` is thrown because macOS blocks Keychain access.

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
2. Click the "Show Storage Location" button
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

Vault Storage has no state management dependency. Use it with Riverpod, Bloc, Provider, GetX, or direct instantiation.

### Basic Usage

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

### File Storage

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

On web, `getFile()` auto-downloads using a filename derived from the stored extension. Custom download filenames are not supported in this API.

### Platform-Specific Behaviour

The package handles platform differences automatically:

- **File retrieval**: Web auto-downloads and returns `Uint8List`; native returns `Uint8List` directly
- **File storage (native)**: Files saved in the app's documents directory
- **File storage (web)**: File bytes stored as `Uint8List` in Hive boxes (browser storage). Legacy base64 data from v3.x is read automatically.
- **MIME types (web)**: Inferred from file extensions for downloads. Unknown types default to `application/octet-stream`.

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
- Per-entry overhead: ~36 bytes (old Map wrapper) to 2 bytes (TypeAdapter)
- One fewer Map allocation and two fewer string lookups on every read/write
- File metadata stored as binary — no JSON encode/decode round-trip
- Web file bytes stored as `Uint8List` directly — no base64 encode/decode per file save/read
- WASM int warning from hive_ce v2.9.0 eliminated

**Migration:**
- Fully automatic — v2.x and v3.x data still read correctly
- Cannot downgrade to v3.x after writing new entries

### V3.0 Performance Improvements

V3.0 reads Lists and Maps 20-50x faster:

- 40-item list: 1000ms to 20ms read time (50x)
- 100-item list: 2500ms to 50ms read time (50x)
- Automatic — no code changes needed

**Migration:**
- Fully automatic — existing code works as-is
- Backward compatible — reads v2.x data without issues
- Cannot downgrade to v2.x after upgrade (v3.x). Cannot downgrade to v3.x after v4.x upgrade.

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

- Android
- iOS
- Web
- macOS
- Windows
- Linux

## License

This project is licensed under the MIT License.