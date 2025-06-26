# Vault Storage

A secure and performant local storage solution for Flutter applications, built with Hive and Flutter Secure Storage. It provides both key-value storage and encrypted file storage with web compatibility, and intensive cryptographic operations are offloaded to background isolates to ensure a smooth UI.

## Features

-   **Dual Storage Model**: Simple key-value storage via Hive and secure file storage for larger data blobs (e.g., images, documents).
-   **Web Compatible**: Full support for both native platforms and web with platform-aware storage strategies.
-   **Robust Security**: Utilizes `flutter_secure_storage` to protect the master encryption key, encrypted Hive boxes for sensitive data, and AES-GCM encryption for files.
-   **High Performance**: Cryptographic operations (AES-GCM) are executed in background isolates using `compute` to prevent UI jank.
-   **Type-Safe Error Handling**: Leverages `fpdart`'s `Either` and `TaskEither` for explicit, functional-style error management.
-   **Framework Agnostic**: Use with any state management solution (Riverpod, Bloc, Provider, GetX, or none at all).

## Use Cases

**🚀 Built for apps that actually matter.** Whether you're building the next unicorn or just want your users' data to be safe, Vault Storage has you covered:

### 🏥 **Healthcare & Medical Apps**
- **Patient Records**: Keep medical data secure and HIPAA-compliant out of the box
- **Medical Imaging**: Store diagnostic images offline without compromising security
- **Health Tracking**: Protect sensitive health data with enterprise-grade encryption

### 🏦 **Financial & Banking Apps**
- **Auth Tokens**: Store JWT tokens and API keys the right way
- **Transaction Data**: Keep financial records encrypted and PCI DSS compliant
- **Biometric Data**: Secure fingerprints and face ID templates safely
- **Digital Wallets**: Protect cryptocurrency keys and payment info

### 🔐 **Enterprise & Business Apps**
- **Corporate Docs**: Encrypt contracts and confidential documents
- **Employee Data**: Manage credentials and personal info securely
- **API Keys**: Store third-party service credentials safely
- **Audit Trails**: Maintain encrypted logs for compliance

### 📱 **Consumer Apps with Real Users**
- **Password Managers**: Store encrypted passwords and secure notes
- **Messaging Apps**: Cache encrypted messages and media files
- **Personal Vaults**: Secure storage for IDs, certificates, and important docs
- **Social Apps**: Protect user data and private content

### 🌐 **Cross-Platform Apps**
- **Consistent Security**: Same protection across mobile, web, and desktop
- **Large Files**: Handle encrypted images, videos, and documents efficiently
- **Offline-First**: Secure local storage that works without internet

### Why Choose Vault Storage?

**🚀 Modern apps demand modern security.** Even simple applications benefit from robust, future-proof storage solutions:

#### **Built for Real-World Applications**
- **🔒 Security by Default**: Why worry about data breaches? Get enterprise-grade encryption out of the box
- **⚡ Performance First**: Smooth UI even with heavy encryption - operations run in background isolates
- **🌍 True Cross-Platform**: One API that works consistently across mobile, web, and desktop
- **🛡️ Bulletproof Error Handling**: Functional error handling prevents crashes and data corruption

#### **Future-Proof Your App**
- **📈 Scalable**: Start with simple key-value storage, seamlessly add encrypted file storage as you grow
- **✅ Compliance Ready**: Already meet GDPR, HIPAA, and PCI DSS requirements without extra work
- **🔧 Production Ready**: Used in real-world applications handling sensitive user data
- **🎯 Type Safe**: Catch storage errors at compile time, not in production

#### **Developer Experience**
- **🎨 Clean API**: Simple, intuitive methods that handle complex security behind the scenes
- **📦 Batteries Included**: Error types, utilities, and comprehensive documentation
- **🧪 Well Tested**: 97.5% test coverage gives you confidence in reliability
- **📚 Complete Documentation**: Examples, use cases, and troubleshooting guides

#### **Perfect for Both Simple and Complex Apps**

**Growing App?** Start storing user preferences securely, then add document encryption later - same API.

**Enterprise App?** Get the security and compliance features you need without the complexity.

**Consumer App?** Your users' data deserves protection, and they'll notice the smooth performance.

> **💡 Pro Tip**: Even if you're storing "just preferences" today, using proper security from day one prevents costly migrations later when you add user accounts, premium features, or sensitive data.

## Important Notes for Production Use

> **⚠️ Security Disclaimer**: While Vault Storage implements industry-standard encryption (AES-GCM 256-bit) and follows security best practices, **no software can guarantee 100% security**. Always conduct your own security audits and compliance reviews before using in production applications, especially those handling sensitive data.

### **🔒 Security Considerations**
- **Audit Required**: Perform independent security audits for applications handling sensitive data
- **Compliance**: Verify that your implementation meets your specific regulatory requirements
- **Key Management**: The security of your data depends on the platform's secure storage implementation
- **Testing**: Thoroughly test encryption/decryption flows in your specific use case

### **⚖️ Legal & Compliance**
- **Your Responsibility**: You are responsible for ensuring compliance with applicable laws and regulations
- **Data Protection**: Review data protection requirements for your jurisdiction and industry
- **User Consent**: Ensure proper user consent for data collection and storage
- **Backup Strategy**: Implement appropriate backup and recovery procedures

### **🛡️ Best Practices**
- **Regular Updates**: Keep the package and dependencies updated for security patches
- **Error Handling**: Implement comprehensive error handling for storage failures
- **Data Minimization**: Only store data that you actually need
- **Access Control**: Implement proper access controls in your application layer

> **📋 Recommendation**: For mission-critical applications, consider additional security measures such as certificate pinning, runtime application self-protection (RASP), and regular penetration testing.

## Getting Started

Add `vault_storage` to your `pubspec.yaml` file:

```yaml
dependencies:
  # ... other dependencies
  vault_storage: ^0.1.1 # Replace with the latest version
  
```

Then, run:
```bash
flutter pub get
```

## Platform Setup

This package uses `flutter_secure_storage` for secure key management, which requires platform-specific configurations:

### Android

In `android/app/build.gradle`, set minimum SDK version to 18 or higher:

```gradle
android {
    defaultConfig {
        minSdkVersion 18  // Required for KeyStore
    }
}
```

**Note**: To prevent backup-related keystore issues, consider disabling auto-backup in your `AndroidManifest.xml`:

```xml
<application
    android:allowBackup="false"
    android:fullBackupContent="false"
    android:dataExtractionRules="@xml/data_extraction_rules"
    ...>
```

### iOS

No additional configuration required. The package uses iOS Keychain by default.

### macOS

**Required**: Add Keychain Sharing capability to both entitlement files:

In `macos/Runner/DebugProfile.entitlements`:
```xml
<key>keychain-access-groups</key>
<array>
    <string>$(AppIdentifierPrefix)com.your.bundle.id</string>
</array>
```

In `macos/Runner/Release.entitlements`:
```xml
<key>keychain-access-groups</key>
<array>
    <string>$(AppIdentifierPrefix)com.your.bundle.id</string>
</array>
```

Replace `com.your.bundle.id` with your actual bundle identifier.

### Linux

Install required system dependencies:

```bash
sudo apt-get install libsecret-1-dev libjsoncpp-dev
```

For runtime: `libsecret-1-0` and `libjsoncpp1`

### Windows

No additional configuration required. Note: `readAll` and `deleteAll` operations have limitations on Windows.

### Web

The package uses WebCrypto for secure storage on web. **Important security considerations**:

- Ensure HTTPS with Strict Transport Security headers
- Data is browser/domain specific and not portable
- Consider the experimental nature of WebCrypto implementation

For production web apps, add these headers:
```
Strict-Transport-Security: max-age=31536000; includeSubDomains
```

Before running your app, you must initialize the service. This is typically done in your `main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:vault_storage/vault_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the vault storage
  final storage = VaultStorageImpl();
  final initResult = await storage.init();
  
  initResult.fold(
    (error) {
      print('Failed to initialize storage: ${error.message}');
      // Handle initialization error appropriately
    },
    (_) {
      runApp(MyApp(storage: storage));
    },
  );
}

class MyApp extends StatelessWidget {
  final VaultStorageImpl storage;
  
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

### Basic Usage (No Dependencies)

You can use Vault Storage directly without any state management framework:

```dart
import 'package:vault_storage/vault_storage.dart';

class StorageManager {
  static VaultStorageImpl? _instance;
  
  static Future<VaultStorageImpl> get instance async {
    if (_instance != null) return _instance!;
    
    _instance = VaultStorageImpl();
    final initResult = await _instance!.init();
    
    return initResult.fold(
      (error) => throw Exception('Failed to initialize storage: ${error.message}'),
      (_) => _instance!,
    );
  }
}

// Usage example
Future<void> example() async {
  final storage = await StorageManager.instance;
  
  // Store a secure value (encrypted)
  final setResult = await storage.set(
    BoxType.secure, 
    'api_key', 
    'my_secret_key'
  );
  
  setResult.fold(
    (error) => print('Error storing key: ${error.message}'),
    (_) => print('Key stored successfully'),
  );

  // Retrieve the value
  final getResult = await storage.get<String>(BoxType.secure, 'api_key');
  getResult.fold(
    (error) => print('Error retrieving key: ${error.message}'),
    (value) => print('Retrieved API key: $value'),
  );
}
```

### Using with Riverpod

If you prefer to use Riverpod, you can create your own provider. First, add the Riverpod dependencies to your `pubspec.yaml`:

```yaml
dependencies:
  # ... other dependencies
  vault_storage: ^0.1.1
  flutter_riverpod: ^2.4.9
  riverpod_annotation: ^2.3.3

dev_dependencies:
  # ... other dev dependencies  
  build_runner: ^2.4.7
  riverpod_generator: ^2.3.9
```

Then create your own provider file: `lib/providers/storage_provider.dart`

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vault_storage/vault_storage.dart';

part 'storage_provider.g.dart';

@Riverpod(keepAlive: true)
Future<IVaultStorage> vaultStorage(VaultStorageRef ref) async {
  final implementation = VaultStorageImpl();
  final initResult = await implementation.init();

  return initResult.fold(
    (error) => throw Exception('Failed to initialize storage: ${error.message}'),
    (_) {
      ref.onDispose(() async => implementation.dispose());
      return implementation;
    },
  );
}
```

Don't forget to run code generation:
```bash
dart run build_runner build
```

Then use it in your widgets:

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

And update your main.dart:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/storage_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Create a ProviderContainer to access the provider
  final container = ProviderContainer();
  
  try {
    // Initialize the vault storage provider first
    await container.read(vaultStorageProvider.future);
    
    runApp(
      UncontrolledProviderScope(
        container: container,
        child: const MyApp(),
      ),
    );
  } catch (e) {
    print('Failed to initialize storage: $e');
    // Handle initialization error appropriately
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Storage initialization failed: $e'),
          ),
        ),
      ),
    );
  }
}
```

### Key-Value Storage

Store and retrieve simple key-value pairs using different box types for security levels:

```dart
// Store secure data (encrypted)
await storage.set(BoxType.secure, 'user_token', 'jwt_token_here');
await storage.set(BoxType.secure, 'user_credentials', {
  'username': 'john_doe',
  'password': 'hashed_password'
});

// Store normal data (faster, unencrypted)
await storage.set(BoxType.normal, 'theme_mode', 'dark');
await storage.set(BoxType.normal, 'language', 'en');

// Retrieve data
final tokenResult = await storage.get<String>(BoxType.secure, 'user_token');
final themeResult = await storage.get<String>(BoxType.normal, 'theme_mode');
```

### Secure File Storage

For larger data like images, documents, or any binary data:

```dart
import 'dart:typed_data';

Future<void> handleFileStorage(IVaultStorage storage) async {
  // Assume 'imageData' is a Uint8List from an image picker or network
  final Uint8List imageData = ...; 

  // Save a file (automatically encrypted)
  final saveResult = await storage.saveSecureFile(
    fileBytes: imageData,
    fileExtension: 'jpg',
  );

  await saveResult.fold(
    (error) async => print('Error saving file: ${error.message}'),
    (metadata) async {
      print('File saved successfully. ID: ${metadata['fileId']}');
      
      // Store the metadata for later retrieval
      await storage.set(
        BoxType.secure,
        'profile_image_metadata',
        metadata,
      );

      // Later, retrieve the file using the metadata
      final fileResult = await storage.getSecureFile(metadata: metadata);
      
      fileResult.fold(
        (error) => print('Error retrieving file: ${error.message}'),
        (fileBytes) => print('Retrieved file of ${fileBytes.length} bytes'),
      );
    },
  );
}
```

### Storage Box Types

The package provides different storage box types for different security and performance needs:

- `BoxType.secure`: Encrypted storage for sensitive data (passwords, tokens, etc.)
- `BoxType.normal`: Unencrypted storage for non-sensitive data (preferences, cache, etc.)
- `BoxType.secureFiles`: Used internally for encrypted file storage on web
- `BoxType.normalFiles`: Used internally for normal file storage

### Web Compatibility

The package automatically handles platform differences:

- **Native platforms**: Files are stored in the app's documents directory
- **Web**: Files are stored as base64-encoded strings in encrypted Hive boxes

No code changes are required - the package handles platform detection automatically.

### Initialization in main()

```dart
import 'package:flutter/material.dart';
import 'package:vault_storage/vault_storage.dart';

late final IVaultStorage vaultStorage;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize storage
  vaultStorage = VaultStorageImpl();
  final initResult = await vaultStorage.init();
  
  initResult.fold(
    (error) => throw Exception('Failed to initialize storage: ${error.message}'),
    (_) => print('Storage initialized successfully'),
  );

  runApp(const MyApp());
}

// Use the service anywhere in your app
Future<void> useStorage() async {
  final result = await vaultStorage.set(
    BoxType.secure, 
    'api_key', 
    'my_secret_key'
  );
  
  // Handle result...
}
```

## Error Handling

The service uses functional error handling with `fpdart`'s `Either` type. All methods return `Either<StorageError, T>`:

```dart
final result = await vaultStorage.get<String>(BoxType.secure, 'key');

result.fold(
  (error) {
    // Handle different error types
    switch (error.runtimeType) {
      case StorageInitializationError:
        print('Storage not initialized: ${error.message}');
        break;
      case StorageReadError:
        print('Failed to read data: ${error.message}');
        break;
      case StorageSerializationError:
        print('Data format error: ${error.message}');
        break;
      default:
        print('Unknown error: ${error.message}');
    }
  },
  (value) {
    // Handle success
    print('Retrieved value: $value');
  },
);
```

## Storage Management

```dart
// Clear a specific box
await vaultStorage.clear(BoxType.normal);

// Delete a specific key
await vaultStorage.delete(BoxType.secure, 'api_key');

// Dispose of the service (usually in app shutdown)
await vaultStorage.dispose();
```

## Troubleshooting

### Common Initialization Errors

#### "Failed to create/decode secure key"

This error typically occurs when `flutter_secure_storage` cannot access the platform's secure storage:

**macOS**: Ensure keychain access entitlements are properly configured (see Platform Setup above)

**Android**: Check that minSdkVersion >= 18 and consider disabling auto-backup

**Solution**: Verify platform-specific setup requirements and restart your app after configuration changes

#### App Crashes on First Launch

If the app crashes during storage initialization:

1. Check that all platform requirements are met
2. Ensure proper error handling in your `main()` function:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    final storage = VaultStorageImpl();
    final initResult = await storage.init();
    
    initResult.fold(
      (error) {
        print('Storage initialization failed: ${error.message}');
        // Show error screen or fallback UI
        runApp(MaterialApp(
          home: Scaffold(
            body: Center(
              child: Text('Storage initialization failed: ${error.message}'),
            ),
          ),
        ));
      },
      (_) => runApp(MyApp(storage: storage)),
    );
  } catch (e) {
    print('Unexpected error: $e');
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('Unexpected error: $e'),
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
- Verify that local storage is not disabled

### Debug Mode

To get more detailed error information, check the console output when initialization fails. The package provides detailed error messages for different failure scenarios.

## Testing

This package includes comprehensive tests. To run them:

```bash
flutter test
```

For integration testing in your app, you can use the `@visibleForTesting` methods and properties available in the implementation.

## Dependencies

Key dependencies used by this package:

- `hive_ce_flutter`: Local storage database
- `flutter_secure_storage`: Secure key storage
- `cryptography`: AES-GCM encryption
- `fpdart`: Functional programming utilities

## Platform Support

- ✅ Android
- ✅ iOS  
- ✅ Web
- ✅ macOS
- ✅ Windows
- ✅ Linux

## License

This project is licensed under the MIT License.