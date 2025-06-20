# Storage Service

A secure and performant local storage solution for Flutter applications, built with Hive, Flutter Secure Storage, and Riverpod. It provides both key-value storage and encrypted file storage, with intensive cryptographic operations offloaded to background isolates to ensure a smooth UI.

## Features

-   **Dual Storage Model**: Simple key-value storage via Hive and secure file storage for larger data blobs (e.g., images, documents).
-   **Robust Security**: Utilizes `flutter_secure_storage` to protect the master encryption key, an encrypted Hive box for sensitive key-value pairs, and per-file encryption for file storage.
-   **High Performance**: Cryptographic operations (AES-GCM) are executed in background isolates using `compute` to prevent UI jank.
-   **Type-Safe Error Handling**: Leverages `fpdart`'s `Either` and `TaskEither` for explicit, functional-style error management.
-   **Ready for Dependency Injection**: Comes with a pre-configured Riverpod provider for easy integration and lifecycle management.

## Getting Started

This is a local package. To use it in your main application, add it as a path dependency in your `pubspec.yaml`:

```yaml
dependencies:
  # ... other dependencies
  vault_storage:
    path: packages/vault_storage
```

Before running your app, you must initialize the service. This is typically done in your `main.dart` or an initialization module.

```dart
// In your main function or an initialization class
import 'package:vault_storage/vault_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Create a ProviderContainer to access the provider.
  final container = ProviderContainer();

  // Initialize the storage service.
  await container.read(storageServiceProvider.future);

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const MyApp(),
    ),
  );
}
```

## Usage

### Key-Value Storage

You can store and retrieve simple key-value pairs using the `set` and `get` methods. The `BoxType` enum determines whether the data is stored in the encrypted `secure` box or the unencrypted `normal` box.

```dart
final storageService = await container.read(storageServiceProvider.future);

// Store a secure value
await storageService.set(BoxType.secure, 'api_key', 'my_secret_key');

// Retrieve a secure value
final apiKey = await storageService.get<String>(BoxType.secure, 'api_key');

apiKey.fold(
  (error) => print('Error retrieving key: ${error.message}'),
  (key) => print('Retrieved API key: $key'),
);
```

### Secure File Storage

For larger data like images or documents, you can use the secure file storage methods.

```dart
import 'dart:typed_data';

// Assume 'imageData' is a Uint8List
final storageService = await container.read(storageServiceProvider.future);

// Save a file
final saveResult = await storageService.saveSecureFile(
  fileBytes: imageData,
  fileExtension: 'png',
);

saveResult.fold(
  (error) => print('Error saving file: ${error.message}'),
  (metadata) async {
    print('File saved successfully. Metadata: $metadata');

    // Retrieve the file
    final getResult = await storageService.getSecureFile(fileMetadata: metadata);

    getResult.fold(
      (error) => print('Error retrieving file: ${error.message}'),
      (fileBytes) => print('Retrieved file with ${fileBytes.length} bytes.'),
    );
  },
);
```

## Error Handling

The service uses `fpdart`'s `Either` for error handling. All methods return an `Either<StorageError, T>`, where `T` is the success type. This forces you to handle potential failures explicitly.

## Testing

This package includes a comprehensive test suite. To run the tests, use the following command:

```bash
flutter test
```