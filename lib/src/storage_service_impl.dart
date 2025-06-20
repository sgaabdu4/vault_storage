import 'dart:convert';
import 'dart:io';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:storage_service/src/constants/storage_keys.dart';
import 'package:storage_service/src/entities/decrypt_request.dart';
import 'package:storage_service/src/entities/encrypt_request.dart';
import 'package:storage_service/src/enum/storage_box_type.dart';
import 'package:storage_service/src/errors/storage_error.dart';
import 'package:storage_service/src/interface/i_storage_service.dart';
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
  final decryptedData = await _algorithm.decrypt(secretBox, secretKey: secretKey);
  return Uint8List.fromList(decryptedData);
}

// ==========================================================================
// Service Implementation
// ==========================================================================

/// The implementation of the storage service.
/// It uses Hive for structured data and encrypted files for binary data.
class StorageServiceImpl implements IStorageService {
  final FlutterSecureStorage _secureStorage;
  final Uuid _uuid;
  @visibleForTesting
  final Map<BoxType, Box<String>> storageBoxes = {};
  @visibleForTesting
  bool isStorageServiceReady = false;

  StorageServiceImpl({FlutterSecureStorage? secureStorage, Uuid? uuid})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _uuid = uuid ?? const Uuid();

  @override
  Future<Either<StorageError, Unit>> init() async {
    if (isStorageServiceReady) return right(unit);

    final task = TaskEither<StorageError, Unit>.tryCatch(
      () async {
        await Hive.initFlutter();
        return unit;
      },
      (e, _) => StorageInitializationError('Failed to initialize Hive', e),
    ).flatMap((_) => getOrCreateSecureKey()).flatMap((key) => openBoxes(key));

    final result = await task.run();
    return result.fold((error) => left(error), (_) {
      isStorageServiceReady = true;
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
      return json.decode(jsonString) as T;
    }, (e) => StorageReadError('Failed to read "$key" from ${box.name} box', e));
  }

  @override
  Future<Either<StorageError, void>> set<T>(BoxType box, String key, T value) {
    return _execute(
      () => _getBox(box).put(key, json.encode(value)),
      (e) => StorageWriteError('Failed to write "$key" to ${box.name} box', e),
    );
  }

  @override
  Future<Either<StorageError, void>> delete(BoxType box, String key) {
    return _execute(
      () => _getBox(box).delete(key),
      (e) => StorageDeleteError('Failed to delete "$key" from ${box.name} box', e),
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
    final operation = TaskEither<StorageError, Map<String, dynamic>>.tryCatch(() async {
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

      await _secureStorage.write(key: secureKeyName, value: base64Url.encode(keyBytes));

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
      final filePath = fileMetadata['filePath'] as String;
      final secureKeyName = fileMetadata['secureKeyName'] as String;
      final nonce = base64Url.decode(fileMetadata['nonce'] as String);
      final macBytes = base64Url.decode(fileMetadata['mac'] as String);

      final encryptedFileBytes = await File(filePath).readAsBytes();

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

      final file = File(filePath);
      if (file.existsSync()) {
        file.deleteSync();
      }

      await _secureStorage.delete(key: secureKeyName);

      return unit;
    }, (e, _) => StorageDeleteError('Failed to delete secure file', e));

    return _executeTask(operation);
  }

  // ==========================================
  // DISPOSE & PRIVATE HELPERS
  // ==========================================

  Future<void> dispose() async {
    if (isStorageServiceReady) {
      await Hive.close();
      storageBoxes.clear();
      isStorageServiceReady = false;
    }
  }

  Future<Either<StorageError, T>> _execute<T>(
    Future<T> Function() operation,
    StorageError Function(Object e) errorBuilder,
  ) {
    return _executeTask(TaskEither.tryCatch(operation, (e, _) => errorBuilder(e)));
  }

  Future<Either<StorageError, T>> _executeTask<T>(TaskEither<StorageError, T> task) {
    if (!isStorageServiceReady) {
      return Future.value(left(const StorageInitializationError('Storage not initialized')));
    }
    return task.mapLeft((l) {
      if (l.originalException is FormatException || l.originalException is JsonUnsupportedObjectError) {
        return StorageSerializationError('${l.message}: ${l.originalException}');
      }
      return l;
    }).run();
  }

  Box<String> _getBox(BoxType type) {
    final box = storageBoxes[type];
    if (box == null) {
      throw Exception('Box $type not opened. Ensure init() was called.');
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
          await _secureStorage.write(key: StorageKeys.secureKey, value: base64UrlEncode(key));
          return key;
        }
        return base64Url.decode(encodedKey);
      }, (e, _) => StorageInitializationError('Failed to create/decode secure key', e));
    });
  }

  @visibleForTesting
  TaskEither<StorageError, Unit> openBoxes(List<int> encryptionKey) {
    return TaskEither.tryCatch(() async {
      storageBoxes[BoxType.secure] = await Hive.openBox<String>(
        StorageKeys.secureBox,
        encryptionCipher: HiveAesCipher(encryptionKey),
      );
      storageBoxes[BoxType.normal] = await Hive.openBox<String>(StorageKeys.normalBox);
      return unit;
    }, (e, _) => StorageInitializationError('Failed to open storage boxes', e));
  }
}
