import 'dart:convert';
// WEB-COMPAT: Conditional import for dart:io
import 'dart:io' if (dart.library.js_interop) 'dart:html' show File;
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
// WEB-COMPAT: Conditional import for path_provider
import 'package:path_provider/path_provider.dart'
    if (dart.library.js_interop) 'package:vault_storage/src/mock/path_provider_mock.dart';
import 'package:vault_storage/src/constants/storage_keys.dart';
import 'package:vault_storage/src/entities/decrypt_request.dart';
import 'package:vault_storage/src/entities/encrypt_request.dart';
import 'package:vault_storage/src/enum/storage_box_type.dart';
import 'package:vault_storage/src/errors/errors.dart';
import 'package:vault_storage/src/extensions/extensions.dart';
import 'package:vault_storage/src/interface/i_vault_storage.dart';
import 'package:uuid/uuid.dart';

final _algorithm = AesGcm.with256bits();

// ==========================================================================
// Isolate Data Models and Functions
// These must be top-level or static to be used with compute().
// ==========================================================================

Future<SecretBox> _encryptInIsolate(EncryptRequest request) async {
  final secretKey = SecretKey(request.keyBytes);
  return _algorithm.encrypt(request.fileBytes, secretKey: secretKey);
}

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

class VaultStorageImpl implements IVaultStorage {
  final FlutterSecureStorage _secureStorage;
  final Uuid _uuid;

  @visibleForTesting
  final Map<BoxType, Box<dynamic>> storageBoxes =
      {}; // WEB-COMPAT: Changed to Box<dynamic>

  @visibleForTesting
  bool isVaultStorageReady = false;

  VaultStorageImpl({FlutterSecureStorage? secureStorage, Uuid? uuid})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _uuid = uuid ?? const Uuid();

  @override
  Future<Either<StorageError, Unit>> init() async {
    if (isVaultStorageReady) return right(unit);

    final task = TaskEither<StorageError, Unit>.tryCatch(
      () async {
        // WEB-COMPAT: Removed subDir for Hive.initFlutter for web compatibility
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
      final jsonString = _getBox(box).get(key) as String?;
      if (jsonString == null) return null;
      
      final decodeResult = JsonSafe.decode<T>(jsonString);
      return decodeResult.fold(
        (error) => throw error,
        (value) => value
      );
    },
        (e) =>
            StorageReadError('Failed to read "$key" from ${box.name} box', e));
  }

  @override
  Future<Either<StorageError, void>> set<T>(BoxType box, String key, T value) {
    return _execute(
      () {
        final encodeResult = JsonSafe.encode(value);
        return encodeResult.fold(
          (error) => throw error,
          (jsonString) => _getBox(box).put(key, jsonString)
        );
      },
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
  // SECURE FILE STORAGE (Now with Web Support)
  // ==========================================

  @override
  Future<Either<StorageError, Map<String, dynamic>>> saveSecureFile({
    required Uint8List fileBytes,
    required String fileExtension,
    @visibleForTesting bool? isWeb,
  }) {
    final operation =
        TaskEither<StorageError, Map<String, dynamic>>.tryCatch(() async {
      final fileId = _uuid.v4();
      final secureKeyName = 'file_key_$fileId';
      final secretKey = await _algorithm.newSecretKey();
      final keyBytes = await secretKey.extractBytes();

      final secretBox = await compute(
        _encryptInIsolate,
        EncryptRequest(fileBytes: fileBytes, keyBytes: keyBytes),
      );

      // WEB-COMPAT: Platform-aware saving logic
      String? filePath; // Nullable for web
      if (isWeb ?? kIsWeb) {
        // WEB: Store the encrypted bytes directly in Hive as a base64 string
        final encryptedContentBase64 = secretBox.cipherText.encodeBase64();
        await _getBox(BoxType.secureFiles).put(fileId, encryptedContentBase64);
      } else {
        // NATIVE: Use path_provider and dart:io to save to a file
        final dir = await getApplicationDocumentsDirectory();
        filePath = '${dir.path}/$fileId.$fileExtension.enc';
        await File(filePath).writeAsBytes(secretBox.cipherText, flush: true);
      }

      await _secureStorage.write(
          key: secureKeyName, value: keyBytes.encodeBase64());

      // Return unified metadata
      return {
        'fileId': fileId, // The universal key for retrieval
        'filePath': filePath, // Path is only present on native platforms
        'secureKeyName': secureKeyName,
        'nonce': secretBox.nonce.encodeBase64(),
        'mac': secretBox.mac.bytes.encodeBase64(),
      };
    }, (e, _) => StorageWriteError('Failed to save secure file', e));

    return _executeTask(operation);
  }

  @override
  Future<Either<StorageError, Uint8List>> getSecureFile({
    required Map<String, dynamic> fileMetadata,
    @visibleForTesting bool? isWeb,
  }) {
    final operation = TaskEither<StorageError, Uint8List>.tryCatch(() async {
      // Extract required fields from metadata
      final fileId = fileMetadata.getRequiredString('fileId');
      final secureKeyName = fileMetadata.getRequiredString('secureKeyName');

      // Decode base64 values from metadata
      final nonceResult = fileMetadata
          .getRequiredString('nonce')
          .decodeBase64Safely(context: 'nonce');
      final macResult = fileMetadata
          .getRequiredString('mac')
          .decodeBase64Safely(context: 'MAC bytes');

      // Extract the bytes using fold
      final nonce = nonceResult.fold((error) => throw error, (bytes) => bytes);

      final macBytes = macResult.fold((error) => throw error, (bytes) => bytes);

      // WEB-COMPAT: Platform-aware retrieval logic
      Uint8List encryptedFileBytes;
      if (isWeb ?? kIsWeb) {
        // WEB: Retrieve from Hive and decode from base64
        final encryptedContentBase64 =
            _getBox(BoxType.secureFiles).get(fileId) as String?;
        if (encryptedContentBase64 == null) {
          throw FileNotFoundError(fileId, 'Hive secure files box');
        }

        final contentResult = encryptedContentBase64.decodeBase64Safely(
            context: 'encrypted content');
        encryptedFileBytes =
            contentResult.fold((error) => throw error, (bytes) => bytes);
      } else {
        // NATIVE: Retrieve from file system
        final filePath = fileMetadata.getOptionalString('filePath');
        if (filePath == null) {
          throw InvalidMetadataError('filePath');
        }

        final file = File(filePath);
        if (!await file.exists()) {
          throw FileNotFoundError(fileId, 'file system at path: $filePath');
        }

        encryptedFileBytes = await file.readAsBytes();
      }

      // Get the encryption key from secure storage
      final keyString = await _secureStorage.read(key: secureKeyName);
      if (keyString == null) {
        throw KeyNotFoundError(secureKeyName);
      }

      final keyResult = keyString.decodeBase64Safely(context: 'encryption key');
      final keyBytes = keyResult.fold((error) => throw error, (bytes) => bytes);

      // Decrypt the file data
      return compute(
        _decryptInIsolate,
        DecryptRequest(
          encryptedBytes: encryptedFileBytes,
          keyBytes: keyBytes,
          nonce: nonce,
          macBytes: macBytes,
        ),
      );
    },
        (e, _) => e is StorageError
            ? e
            : StorageReadError('Failed to read secure file', e));

    return _executeTask(operation);
  }

  @override
  Future<Either<StorageError, Unit>> deleteSecureFile({
    required Map<String, dynamic> fileMetadata,
    @visibleForTesting bool? isWeb,
  }) {
    final operation = TaskEither<StorageError, Unit>.tryCatch(() async {
      final fileId = fileMetadata.getRequiredString('fileId');
      final secureKeyName = fileMetadata.getRequiredString('secureKeyName');

      // WEB-COMPAT: Platform-aware deletion logic
      if (isWeb ?? kIsWeb) {
        // WEB: Delete from Hive
        await _getBox(BoxType.secureFiles).delete(fileId);
      } else {
        // NATIVE: Delete from file system
        final filePath = fileMetadata.getOptionalString('filePath');
        if (filePath != null) {
          final file = File(filePath);
          if (await file.exists()) {
            await file.delete();
          }
        }
      }

      // Delete the encryption key
      await _secureStorage.delete(key: secureKeyName);
      return unit;
    }, (e, _) => StorageDeleteError('Failed to delete secure file', e));

    return _executeTask(operation);
  }

  // ==========================================
  // NORMAL FILE STORAGE
  // ==========================================

  @override
  Future<Either<StorageError, Map<String, dynamic>>> saveNormalFile({
    required Uint8List fileBytes,
    required String fileExtension,
    @visibleForTesting bool? isWeb,
  }) {
    final operation =
        TaskEither<StorageError, Map<String, dynamic>>.tryCatch(() async {
      final fileId = _uuid.v4();

      // Platform-aware saving logic
      String? filePath; // Nullable for web
      if (isWeb ?? kIsWeb) {
        // WEB: Store the bytes directly in Hive as a base64 string
        final contentBase64 = fileBytes.encodeBase64();
        await _getBox(BoxType.normalFiles).put(fileId, contentBase64);
      } else {
        // NATIVE: Use path_provider and dart:io to save to a file
        final dir = await getApplicationDocumentsDirectory();
        filePath = '${dir.path}/$fileId.$fileExtension';
        await File(filePath).writeAsBytes(fileBytes, flush: true);
      }

      // Return metadata
      return {
        'fileId': fileId,
        'filePath': filePath,
        'extension': fileExtension,
      };
    }, (e, _) => StorageWriteError('Failed to save normal file', e));

    return _executeTask(operation);
  }

  @override
  Future<Either<StorageError, Uint8List>> getNormalFile({
    required Map<String, dynamic> fileMetadata,
    @visibleForTesting bool? isWeb,
  }) {
    final operation = TaskEither<StorageError, Uint8List>.tryCatch(() async {
      // Extract required fields from metadata
      final fileId = fileMetadata.getRequiredString('fileId');

      // Platform-aware retrieval logic
      if (isWeb ?? kIsWeb) {
        // WEB: Retrieve from Hive and decode from base64
        final contentBase64 =
            _getBox(BoxType.normalFiles).get(fileId) as String?;
        if (contentBase64 == null) {
          throw FileNotFoundError(fileId, 'Hive normal files box');
        }

        // Use our extension method for cleaner code
        final result =
            contentBase64.decodeBase64Safely(context: 'normal file content');
        return result.fold(
            (error) =>
                throw error, // Re-throw the Base64DecodeError to be caught by the outer tryCatch
            (bytes) => bytes);
      } else {
        // NATIVE: Retrieve from file system
        final filePath = fileMetadata.getOptionalString('filePath');
        if (filePath == null) {
          throw InvalidMetadataError('filePath');
        }

        final file = File(filePath);
        if (!await file.exists()) {
          throw FileNotFoundError(fileId, 'file system at path: $filePath');
        }

        return await file.readAsBytes();
      }
    },
        (e, _) => e is StorageError
            ? e
            : StorageReadError('Failed to retrieve normal file', e));

    return _executeTask(operation);
  }

  @override
  Future<Either<StorageError, Unit>> deleteNormalFile({
    required Map<String, dynamic> fileMetadata,
    @visibleForTesting bool? isWeb,
  }) {
    final operation = TaskEither<StorageError, Unit>.tryCatch(() async {
      final fileId = fileMetadata.getRequiredString('fileId');

      // Platform-aware deletion
      if (isWeb ?? kIsWeb) {
        // WEB: Remove from Hive
        await _getBox(BoxType.normalFiles).delete(fileId);
      } else {
        // NATIVE: Delete the file from the file system
        final filePath = fileMetadata.getOptionalString('filePath');
        if (filePath != null) {
          final file = File(filePath);
          if (await file.exists()) {
            await file.delete();
          }
        }
      }

      return unit;
    }, (e, _) => StorageDeleteError('Failed to delete normal file', e));

    return _executeTask(operation);
  }

  // ==========================================
  // DISPOSE & PRIVATE HELPERS
  // ==========================================

  @override
  Future<Either<StorageError, Unit>> dispose() {
    final task = TaskEither<StorageError, Unit>.tryCatch(
      () async {
        if (isVaultStorageReady) {
          await Hive.close();
          storageBoxes.clear();
          isVaultStorageReady = false;
        }
        return unit;
      },
      (e, _) => StorageDisposalError('Failed to dispose vault storage', e),
    );
    return task.run();
  }

  Future<Either<StorageError, T>> _execute<T>(
    Future<T> Function() operation,
    StorageError Function(Object e) errorBuilder,
  ) {
    return _executeTask(
        TaskEither.tryCatch(operation, (e, _) => errorBuilder(e)));
  }

  Future<Either<StorageError, T>> _executeTask<T>(
      TaskEither<StorageError, T> task) {
    if (!isVaultStorageReady) {
      return Future.value(
          left(const StorageInitializationError('Storage not initialized')));
    }
    return task.mapLeft((l) {
      // Base64DecodeError is already a StorageReadError subclass, no need to remap

      // JSON serialization errors are mapped to StorageSerializationError
      if (l.originalException is JsonUnsupportedObjectError ||
          (l.originalException is FormatException &&
              !(l is Base64DecodeError))) {
        return StorageSerializationError(
            '${l.message}: ${l.originalException}');
      }
      return l;
    }).run();
  }

  // WEB-COMPAT: Changed to return Box<dynamic>
  Box<dynamic> _getBox(BoxType type) {
    final box = storageBoxes[type];
    if (box == null) {
      throw StorageInitializationError(
          'Box ${type.name} not opened. Ensure init() was called.');
    }
    return box;
  }

  @visibleForTesting
  TaskEither<StorageError, List<int>> getOrCreateSecureKey() {
    return TaskEither.tryCatch(
      () => _secureStorage.read(key: StorageKeys.secureKey),
      (e, _) => StorageInitializationError('Failed to read secure key', e),
    ).flatMap((encodedKey) {
      return TaskEither.tryCatch(() async {
        if (encodedKey == null) {
          final key = Hive.generateSecureKey();
          await _secureStorage.write(
              key: StorageKeys.secureKey, value: key.encodeBase64());
          return key;
        }
        final decodeResult =
            encodedKey.decodeBase64Safely(context: 'secure storage key');
        return decodeResult.fold(
            (error) => throw error, (decodedKey) => decodedKey);
      },
          (e, _) => StorageInitializationError(
              'Failed to create/decode secure key', e));
    });
  }

  @visibleForTesting
  TaskEither<StorageError, Unit> openBoxes(List<int> encryptionKey) {
    return TaskEither.tryCatch(() async {
      final cipher = HiveAesCipher(encryptionKey);
      storageBoxes[BoxType.secure] = await Hive.openBox<String>(
        StorageKeys.secureBox,
        encryptionCipher: cipher,
      );
      storageBoxes[BoxType.normal] =
          await Hive.openBox<String>(StorageKeys.normalBox);

      // WEB-COMPAT: Open the new box for files, also encrypted
      storageBoxes[BoxType.secureFiles] = await Hive.openBox<String>(
        StorageKeys
            .secureFilesBox, // Make sure this is defined in your constants
        encryptionCipher: cipher,
      );

      // Open normal files box without encryption
      storageBoxes[BoxType.normalFiles] =
          await Hive.openBox<String>(StorageKeys.normalFilesBox);

      return unit;
    }, (e, _) => StorageInitializationError('Failed to open storage boxes', e));
  }
}
