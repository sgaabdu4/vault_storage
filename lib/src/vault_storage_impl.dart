import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:vault_storage/src/constants/storage_keys.dart';
import 'package:vault_storage/src/enum/storage_box_type.dart';
import 'package:vault_storage/src/errors/errors.dart';
import 'package:vault_storage/src/extensions/extensions.dart';
import 'package:vault_storage/src/interface/i_vault_storage.dart';
import 'package:vault_storage/src/storage/file_operations.dart';
import 'package:vault_storage/src/storage/task_execution.dart';

/// Main implementation of the [IVaultStorage] interface.
///
/// Provides secure and normal storage for key-value pairs and files,
/// with platform-aware implementations for both web and native platforms.
class VaultStorageImpl implements IVaultStorage {
  final FlutterSecureStorage _secureStorage;
  final Uuid _uuid;
  final TaskExecutor _taskExecutor;
  final FileOperations _fileOperations;

  @visibleForTesting
  final Map<BoxType, Box<dynamic>> storageBoxes = {};

  @visibleForTesting
  bool isVaultStorageReady = false;

  /// Creates a new [VaultStorageImpl] instance.
  ///
  /// Optionally, you can provide custom implementations of [FlutterSecureStorage]
  /// and [Uuid] for testing purposes.
  VaultStorageImpl({
    FlutterSecureStorage? secureStorage,
    Uuid? uuid,
    TaskExecutor? taskExecutor,
    FileOperations? fileOperations,
  })  : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _uuid = uuid ?? const Uuid(),
        _taskExecutor = taskExecutor ?? TaskExecutor(),
        _fileOperations = fileOperations ?? FileOperations();

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
    return _taskExecutor.execute<T?>(
      () async {
        final jsonString = _getBox(box).get(key) as String?;
        if (jsonString == null) return null;

        return jsonString.decodeJsonSafely<T>().fold((error) => throw error, (value) => value);
      },
      (e) => StorageReadError('Failed to read "$key" from ${box.name} box', e),
      isStorageReady: isVaultStorageReady,
    );
  }

  @override
  Future<Either<StorageError, void>> set<T>(BoxType box, String key, T value) {
    return _taskExecutor.execute(
      () {
        return value.encodeJsonSafely().fold(
              (error) => throw error,
              (jsonString) => _getBox(box).put(key, jsonString),
            );
      },
      (e) => StorageWriteError('Failed to write "$key" to ${box.name} box', e),
      isStorageReady: isVaultStorageReady,
    );
  }

  @override
  Future<Either<StorageError, void>> delete(BoxType box, String key) {
    return _taskExecutor.execute(
      () => _getBox(box).delete(key),
      (e) => StorageDeleteError('Failed to delete "$key" from ${box.name} box', e),
      isStorageReady: isVaultStorageReady,
    );
  }

  @override
  Future<Either<StorageError, void>> clear(BoxType box) {
    return _taskExecutor.execute(
      () async => await _getBox(box).clear(),
      (e) => StorageDeleteError('Failed to clear ${box.name} box', e),
      isStorageReady: isVaultStorageReady,
    );
  }

  // ==========================================
  // SECURE FILE STORAGE
  // ==========================================

  @override
  Future<Either<StorageError, Map<String, dynamic>>> saveSecureFile({
    required Uint8List fileBytes,
    required String fileExtension,
    @visibleForTesting bool? isWeb,
  }) {
    return _fileOperations.saveSecureFile(
      fileBytes: fileBytes,
      fileExtension: fileExtension,
      isWeb: isWeb,
      secureStorage: _secureStorage,
      uuid: _uuid,
      getBox: _getBox,
      isStorageReady: isVaultStorageReady,
    );
  }

  @override
  Future<Either<StorageError, Uint8List>> getSecureFile({
    required Map<String, dynamic> fileMetadata,
    @visibleForTesting bool? isWeb,
  }) {
    return _fileOperations.getSecureFile(
      fileMetadata: fileMetadata,
      isWeb: isWeb,
      secureStorage: _secureStorage,
      getBox: _getBox,
      isStorageReady: isVaultStorageReady,
    );
  }

  @override
  Future<Either<StorageError, Unit>> deleteSecureFile({
    required Map<String, dynamic> fileMetadata,
    @visibleForTesting bool? isWeb,
  }) {
    return _fileOperations.deleteSecureFile(
      fileMetadata: fileMetadata,
      isWeb: isWeb,
      secureStorage: _secureStorage,
      getBox: _getBox,
      isStorageReady: isVaultStorageReady,
    );
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
    return _fileOperations.saveNormalFile(
      fileBytes: fileBytes,
      fileExtension: fileExtension,
      isWeb: isWeb,
      uuid: _uuid,
      getBox: _getBox,
      isStorageReady: isVaultStorageReady,
    );
  }

  @override
  Future<Either<StorageError, Uint8List>> getNormalFile({
    required Map<String, dynamic> fileMetadata,
    @visibleForTesting bool? isWeb,
  }) {
    return _fileOperations.getNormalFile(
      fileMetadata: fileMetadata,
      isWeb: isWeb,
      getBox: _getBox,
      isStorageReady: isVaultStorageReady,
    );
  }

  @override
  Future<Either<StorageError, Unit>> deleteNormalFile({
    required Map<String, dynamic> fileMetadata,
    @visibleForTesting bool? isWeb,
  }) {
    return _fileOperations.deleteNormalFile(
      fileMetadata: fileMetadata,
      isWeb: isWeb,
      getBox: _getBox,
      isStorageReady: isVaultStorageReady,
    );
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

  /// Get a box from storage, throwing an error if it's not opened
  Box<dynamic> _getBox(BoxType type) {
    final box = storageBoxes[type];
    if (box == null) {
      throw StorageInitializationError('Box ${type.name} not opened. Ensure init() was called.');
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
          await _secureStorage.write(key: StorageKeys.secureKey, value: key.encodeBase64());
          return key;
        }
        final decodeResult = encodedKey.decodeBase64Safely(context: 'secure storage key');
        return decodeResult.fold((error) => throw error, (decodedKey) => decodedKey);
      }, (e, _) => StorageInitializationError('Failed to create/decode secure key', e));
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
      storageBoxes[BoxType.normal] = await Hive.openBox<String>(StorageKeys.normalBox);

      storageBoxes[BoxType.secureFiles] = await Hive.openBox<String>(
        StorageKeys.secureFilesBox,
        encryptionCipher: cipher,
      );

      storageBoxes[BoxType.normalFiles] = await Hive.openBox<String>(StorageKeys.normalFilesBox);

      return unit;
    }, (e, _) => StorageInitializationError('Failed to open storage boxes', e));
  }
}
