# Vault Storage

A secure and performant local storage solution for Flutter applications, built with Hive, Flutter Secure Storage, and Riverpod. It provides both key-value storage and encrypted file storage with web compatibility, and intensive cryptographic operations are offloaded to background isolates to ensure a smooth UI.

> **Note**: This package uses Riverpod with code generation. Make sure to run `dart run build_runner build` after adding this package to generate the necessary provider files.

## Features

-   **Dual Storage Model**: Simple key-value storage via Hive and secure file storage for larger data blobs (e.g., images, documents).
-   **Web Compatible**: Full support for both native platforms and web with platform-aware storage strategies.
-   **Robust Security**: Utilizes `flutter_secure_storage` to protect the master encryption key, encrypted Hive boxes for sensitive data, and AES-GCM encryption for files.
-   **High Performance**: Cryptographic operations (AES-GCM) are executed in background isolates using `compute` to prevent UI jank.
-   **Type-Safe Error Handling**: Leverages `fpdart`'s `Either` and `TaskEither` for explicit, functional-style error management.
-   **Ready for Dependency Injection**: Comes with a pre-configured Riverpod provider for easy integration and lifecycle management.

## Getting Started

Add `vault_storage` to your `pubspec.yaml` file:

```yaml
dependencies:
  # ... other dependencies
  vault_storage: ^0.0.4 # Replace with the latest version
  
```

Then, run:
```bash
flutter pub get
```

> **Note**: This package uses the development version of Riverpod (3.0.0-dev.16) for the latest features. The generated provider files are already included, so you don't need to run code generation yourself.

Before running your app, you must initialize the service. This is typically done in your `main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vault_storage/vault_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Create a ProviderContainer to access the provider
  final container = ProviderContainer();

  try {
    // Initialize the vault storage
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
  }
}
```

## Usage

### Using with Riverpod (Recommended)

#### Key-Value Storage

Store and retrieve simple key-value pairs using different box types for security levels:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vault_storage/vault_storage.dart';

class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder(
      future: _handleStorage(ref),
      builder: (context, snapshot) {
        // Handle UI based on storage operations
        return Container();
      },
    );
  }

  Future<void> _handleStorage(WidgetRef ref) async {
    final vaultStorage = await ref.read(vaultStorageProvider.future);

    // Store a secure value (encrypted)
    final setResult = await vaultStorage.set(
      BoxType.secure, 
      'api_key', 
      'my_secret_key'
    );
    
    setResult.fold(
      (error) => print('Error storing key: ${error.message}'),
      (_) => print('Key stored successfully'),
    );

    // Store a normal value (unencrypted, faster access)
    await vaultStorage.set(
      BoxType.normal, 
      'user_preference', 
      'dark_mode'
    );

    // Retrieve values
    final apiKeyResult = await vaultStorage.get<String>(
      BoxType.secure, 
      'api_key'
    );

    apiKeyResult.fold(
      (error) => print('Error retrieving key: ${error.message}'),
      (key) => print('Retrieved API key: $key'),
    );
  }
}
```

#### Secure File Storage

For larger data like images, documents, or any binary data:

```dart
import 'dart:typed_data';
import 'package:vault_storage/vault_storage.dart';

Future<void> handleFileStorage(WidgetRef ref) async {
  final vaultStorage = await ref.read(vaultStorageProvider.future);
  
  // Assume 'imageData' is a Uint8List from an image picker or network
  final Uint8List imageData = ...; 

  // Save a file (automatically encrypted)
  final saveResult = await vaultStorage.saveSecureFile(
    fileBytes: imageData,
    fileExtension: 'jpg',
  );

  await saveResult.fold(
    (error) async => print('Error saving file: ${error.message}'),
    (metadata) async {
      print('File saved successfully. ID: ${metadata['fileId']}');
      
      // Store the metadata for later retrieval
      await vaultStorage.set(
        BoxType.secure,
        'profile_image_metadata',
        metadata,
      );

      // Retrieve the file
      final getResult = await vaultStorage.getSecureFile(
        fileMetadata: metadata,
      );

      getResult.fold(
        (error) => print('Error retrieving file: ${error.message}'),
        (fileBytes) => print('Retrieved file with ${fileBytes.length} bytes'),
      );

      // Delete the file when no longer needed
      final deleteResult = await vaultStorage.deleteSecureFile(
        fileMetadata: metadata,
      );
      
      deleteResult.fold(
        (error) => print('Error deleting file: ${error.message}'),
        (_) => print('File deleted successfully'),
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

## Manual Usage (Without Riverpod)

If you prefer not to use Riverpod, you can manage the service directly:

```dart
import 'package:vault_storage/src/vault_storage_impl.dart';

// Global instance (or use your preferred DI solution)
late final IVaultStorage vaultStorage;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Create and initialize the service
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
- `riverpod_annotation`: Code generation for providers

## Platform Support

- ✅ Android
- ✅ iOS  
- ✅ Web
- ✅ macOS
- ✅ Windows
- ✅ Linux

## License

This project is licensed under the MIT License.