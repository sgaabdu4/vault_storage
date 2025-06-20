import 'dart:convert';
import 'dart:io';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vault_storage/src/constants/storage_keys.dart';
import 'package:vault_storage/src/entities/decrypt_request.dart';
import 'package:vault_storage/src/entities/encrypt_request.dart';
import 'package:vault_storage/src/enum/storage_box_type.dart';
import 'package:vault_storage/src/errors/storage_error.dart';
import 'package:vault_storage/src/interface/i_vault_storage.dart';
import 'package:uuid/uuid.dart';

final _algorithm = AesGcm.with256bits();

// ==========================================================================
// Isolate Data Models and Functions
// These must be top-level or static to be used with compute().
// ==========================================================================

/// The function that will run in the background isolate to encrypt data.
Future<SecretBox> _encryptInIsolate(EncryptRequest request) async {
  final secretKey = SecretKey(request.keyBytes);
  return _algorithm.encrypt(request.fileBytes, secretKey: secretKey);
}

/// The function that will run in the background isolate to decrypt data.
Future<Uint8List> _decryptInIsolate(DecryptRequest request) async {
  final secretKey = SecretKey(request.keyBytes);
  final secretBox = SecretBox(
    request.encryptedBytes,
    nonce: request.nonce,
    mac: Mac(request.macBytes),
  );
  final decryptedData =
      await _algorithm.decrypt(secretBox, secretKey: secretKey);
  return Uint8List.fromList(decryptedData);
}

// ==========================================================================
// Service Implementation
// ==========================================================================

/// An implementation of the [IVaultStorage] that uses Hive for key-value
/// storage and a custom file-based solution for secure, encrypted file storage.
///
/// This service is designed to be robust and performant, offloading heavy
/// cryptographic operations to background isolates to prevent UI jank. It uses
/// `flutter_secure_storage` to safeguard the master encryption key for Hive.
///
/// The service must be initialized via the [init] method before use. It provides
/// methods for CRUD operations on two types of Hive boxes (`secure` and `normal`)
/// and for saving, retrieving, and deleting encrypted files.
class VaultStorageImpl implements IVaultStorage {
  /// A client for interacting with the platform's secure storage (e.g., Keychain, Keystore).
  final FlutterSecureStorage _secureStorage;

  /// A UUID generator used for creating unique file identifiers.
  final Uuid _uuid;

  /// A map holding the opened Hive boxes, keyed by their [BoxType].
  /// This is marked as `@visibleForTesting` to allow for easier testing.
  @visibleForTesting
  final Map<BoxType, Box<String>> storageBoxes = {};

  /// A flag indicating whether the service has been successfully initialized.
  /// This is marked as `@visibleForTesting` to allow for easier testing.
  @visibleForTesting
  bool isVaultStorageReady = false;

  /// Creates a new instance of [VaultStorageImpl].
  ///
  /// If [secureStorage] or [uuid] are not provided, it defaults to their
  /// standard implementations. This allows for dependency injection during testing.
  VaultStorageImpl({FlutterSecureStorage? secureStorage, Uuid? uuid})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _uuid = uuid ?? const Uuid();

  @override
  Future<Either<StorageError, Unit>> init() async {
    if (isVaultStorageReady) return right(unit);

    final task = TaskEither<StorageError, Unit>.tryCatch(
      () async {
        await Hive.initFlutter();
        return unit;
      },
      (e, _) => StorageInitializationError('Failed to initialize Hive', e),
    ).flatMap((_) => getOrCreateSecureKey()).flatMap((key) => openBoxes(key));

    final result = await task.run();
    return result.fold((error) => left(error), (_) {
      isVaultStorageReady = true;
      return right(unit);
    });
  }

  // ==========================================
  // HIVE KEY-VALUE STORAGE
  // ==========================================

  @override
  Future<Either<StorageError, T?>> get<T>(BoxType box, String key) {
    return _execute<T?>(() async {
      final jsonString = _getBox(box).get(key);
      if (jsonString == null) return null;
      // Assuming the value is stored as a JSON string.
      return json.decode(jsonString) as T;
    },
        (e) =>
            StorageReadError('Failed to read "$key" from ${box.name} box', e));
  }

  @override
  Future<Either<StorageError, void>> set<T>(BoxType box, String key, T value) {
    return _execute(
      // The value is encoded to a JSON string before being stored.
      () => _getBox(box).put(key, json.encode(value)),
      (e) => StorageWriteError('Failed to write "$key" to ${box.name} box', e),
    );
  }

  @override
  Future<Either<StorageError, void>> delete(BoxType box, String key) {
    return _execute(
      () => _getBox(box).delete(key),
      (e) =>
          StorageDeleteError('Failed to delete "$key" from ${box.name} box', e),
    );
  }

  @override
  Future<Either<StorageError, void>> clear(BoxType box) {
    return _execute(
      () async => await _getBox(box).clear(),
      (e) => StorageDeleteError('Failed to clear ${box.name} box', e),
    );
  }

  // ==========================================
  // SECURE FILE STORAGE
  // ==========================================

  @override
  Future<Either<StorageError, Map<String, dynamic>>> saveSecureFile({
    required Uint8List fileBytes,
    required String fileExtension,
  }) {
    final operation =
        TaskEither<StorageError, Map<String, dynamic>>.tryCatch(() async {
      final fileId = _uuid.v4();
      final secureKeyName = 'file_key_$fileId';
      final secretKey = await _algorithm.newSecretKey();
      final keyBytes = await secretKey.extractBytes();

      // HEAVY LIFTING: Run encryption in a background isolate.
      final secretBox = await compute(
        _encryptInIsolate,
        EncryptRequest(fileBytes: fileBytes, keyBytes: keyBytes),
      );

      final dir = await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/$fileId.$fileExtension.enc';
      await File(filePath).writeAsBytes(secretBox.cipherText, flush: true);

      // Store the file-specific encryption key securely.
      await _secureStorage.write(
          key: secureKeyName, value: base64Url.encode(keyBytes));

      // Return metadata needed for decryption and file management.
      return {
        'filePath': filePath,
        'secureKeyName': secureKeyName,
        'nonce': base64Url.encode(secretBox.nonce),
        'mac': base64Url.encode(secretBox.mac.bytes),
      };
    }, (e, _) => StorageWriteError('Failed to save secure file', e));

    return _executeTask(operation);
  }

  @override
  Future<Either<StorageError, Uint8List>> getSecureFile({
    required Map<String, dynamic> fileMetadata,
  }) {
    final operation = TaskEither<StorageError, Uint8List>.tryCatch(() async {
      // Extract metadata needed for decryption.
      final filePath = fileMetadata['filePath'] as String;
      final secureKeyName = fileMetadata['secureKeyName'] as String;
      final nonce = base64Url.decode(fileMetadata['nonce'] as String);
      final macBytes = base64Url.decode(fileMetadata['mac'] as String);

      final encryptedFileBytes = await File(filePath).readAsBytes();

      // Retrieve the file-specific encryption key.
      final keyString = await _secureStorage.read(key: secureKeyName);
      if (keyString == null) {
        throw Exception('File key not found in secure storage.');
      }
      final keyBytes = base64Url.decode(keyString);

      // HEAVY LIFTING: Run decryption in a background isolate.
      return compute(
        _decryptInIsolate,
        DecryptRequest(
          encryptedBytes: encryptedFileBytes,
          keyBytes: keyBytes,
          nonce: nonce,
          macBytes: macBytes,
        ),
      );
    }, (e, _) => StorageReadError('Failed to read secure file', e));

    return _executeTask(operation);
  }

  @override
  Future<Either<StorageError, Unit>> deleteSecureFile({
    required Map<String, dynamic> fileMetadata,
  }) {
    final operation = TaskEither<StorageError, Unit>.tryCatch(() async {
      final filePath = fileMetadata['filePath'] as String;
      final secureKeyName = fileMetadata['secureKeyName'] as String;

      // Delete the encrypted file from the filesystem.
      final file = File(filePath);
      if (file.existsSync()) {
        file.deleteSync();
      }

      // Delete the file's encryption key from secure storage.
      await _secureStorage.delete(key: secureKeyName);

      return unit;
    }, (e, _) => StorageDeleteError('Failed to delete secure file', e));

    return _executeTask(operation);
  }

  // ==========================================
  // DISPOSE & PRIVATE HELPERS
  // ==========================================

  /// Closes all open Hive boxes and resets the service's ready state.
  ///
  /// This method should be called when the service is no longer needed, such as
  /// when the application is shutting down, to ensure all resources are released.
  Future<void> dispose() async {
    if (isVaultStorageReady) {
      await Hive.close();
      storageBoxes.clear();
      isVaultStorageReady = false;
    }
  }

  /// A private helper to execute a storage operation and wrap it in an `Either`.
  ///
  /// This method simplifies error handling by catching exceptions and converting
  /// them into a `StorageError` type, which is returned on the `Left` side of
  /// the `Either`. Successful results are returned on the `Right` side.
  ///
  /// - [operation]: The asynchronous function to execute.
  /// - [errorBuilder]: A function that creates a `StorageError` from a caught exception.
  Future<Either<StorageError, T>> _execute<T>(
    Future<T> Function() operation,
    StorageError Function(Object e) errorBuilder,
  ) {
    return _executeTask(
        TaskEither.tryCatch(operation, (e, _) => errorBuilder(e)));
  }

  /// Executes a [TaskEither] and performs pre-execution checks.
  ///
  /// This helper ensures that the vault storage is initialized before any
  /// operation is attempted. If not, it returns a `StorageInitializationError`.
  /// It also handles JSON serialization errors specifically.
  Future<Either<StorageError, T>> _executeTask<T>(
      TaskEither<StorageError, T> task) {
    if (!isVaultStorageReady) {
      return Future.value(
          left(const StorageInitializationError('Storage not initialized')));
    }
    // Enhance error handling to specifically catch serialization issues.
    return task.mapLeft((l) {
      if (l.originalException is FormatException ||
          l.originalException is JsonUnsupportedObjectError) {
        return StorageSerializationError(
            '${l.message}: ${l.originalException}');
      }
      return l;
    }).run();
  }

  /// Retrieves an opened Hive box of a specific [type].
  ///
  /// Throws an exception if the requested box has not been opened, which would
  /// indicate a programming error (e.g., calling this before `init` completes).
  Box<String> _getBox(BoxType type) {
    final box = storageBoxes[type];
    if (box == null) {
      throw Exception('Box $type not opened. Ensure init() was called.');
    }
    return box;
  }

  /// Retrieves the master encryption key from secure storage, or creates a new one.
  ///
  /// This is a critical step in the initialization process. If a key exists, it's
  /// read and decoded. If not, a new 256-bit key is generated and stored securely
  /// for future use.
  /// This is marked as `@visibleForTesting` to allow for easier testing.
  @visibleForTesting
  TaskEither<StorageError, List<int>> getOrCreateSecureKey() {
    return TaskEither.tryCatch(
      () => _secureStorage.read(key: StorageKeys.secureKey),
      (e, _) => StorageInitializationError('Failed to read secure key', e),
    ).flatMap((encodedKey) {
      return TaskEither.tryCatch(() async {
        if (encodedKey == null) {
          // Generate a new key if one doesn't exist.
          final key = Hive.generateSecureKey();
          await _secureStorage.write(
              key: StorageKeys.secureKey, value: base64UrlEncode(key));
          return key;
        }
        // Decode the existing key.
        return base64Url.decode(encodedKey);
      },
          (e, _) => StorageInitializationError(
              'Failed to create/decode secure key', e));
    });
  }

  /// Opens the normal and secure Hive boxes.
  ///
  /// The secure box is opened with the provided [encryptionKey], ensuring its
  /// contents are encrypted on disk. The opened boxes are stored in the
  /// [storageBoxes] map.
  /// This is marked as `@visibleForTesting` to allow for easier testing.
  @visibleForTesting
  TaskEither<StorageError, Unit> openBoxes(List<int> encryptionKey) {
    return TaskEither.tryCatch(() async {
      storageBoxes[BoxType.secure] = await Hive.openBox<String>(
        StorageKeys.secureBox,
        encryptionCipher: HiveAesCipher(encryptionKey),
      );
      storageBoxes[BoxType.normal] =
          await Hive.openBox<String>(StorageKeys.normalBox);
      return unit;
    }, (e, _) => StorageInitializationError('Failed to open storage boxes', e));
  }
}
