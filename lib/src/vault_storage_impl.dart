import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:vault_storage/src/constants/storage_keys.dart';
import 'package:vault_storage/src/constants/vault_storage_config.dart';
import 'package:vault_storage/src/entities/box_config.dart';
import 'package:vault_storage/src/entities/file_services.dart';
import 'package:vault_storage/src/entities/normal_file_request.dart';
import 'package:vault_storage/src/entities/secure_file_request.dart';
import 'package:vault_storage/src/entities/secure_file_stream_request.dart';
import 'package:vault_storage/src/enum/box_type.dart';
import 'package:vault_storage/src/errors/errors.dart';
import 'package:vault_storage/src/extensions/extensions.dart';
import 'package:vault_storage/src/interface/i_file_operations.dart';
import 'package:vault_storage/src/interface/i_id_generator.dart';
import 'package:vault_storage/src/interface/i_secure_key_store.dart';
import 'package:vault_storage/src/interface/i_vault_storage.dart';
import 'package:vault_storage/src/mock/freerasp_mock.dart'
    if (dart.library.io) 'package:freerasp/freerasp.dart';
import 'package:vault_storage/src/security/security_exceptions.dart';
import 'package:vault_storage/src/security/vault_security_config.dart';
import 'package:vault_storage/src/storage/file_metadata_keys.dart';
import 'package:vault_storage/src/storage/storage_strategy.dart';
import 'package:vault_storage/src/storage/stored_file_keys.dart';
import 'package:vault_storage/src/storage/stored_value_adapter.dart';
import 'package:vault_storage/src/storage/vault_storage_adapter_registry.dart';
import 'package:vault_storage/src/utils/concurrency.dart';

part 'vault_storage_impl_boxes.dart';
part 'vault_storage_impl_files.dart';
part 'vault_storage_impl_init.dart';
part 'vault_storage_impl_security.dart';

const _customBoxReadConcurrency = 4;

/// Simple, secure storage implementation for Flutter apps.
class VaultStorageImpl implements IVaultStorage {
  final ISecureKeyStore _secureStorage;
  final IIdGenerator _uuid;
  final IFileOperations _fileOperations;
  final VaultSecurityConfig? _securityConfig;
  final List<BoxConfig> _customBoxConfigs;
  final String? _storageDirectory;
  final VaultStorageConfig _config;

  @visibleForTesting
  final bool isAdapterRegistered = _registerAdapters();

  @visibleForTesting
  final Map<BoxType, BoxBase<Object?>> boxes = {};

  @visibleForTesting
  final Map<String, BoxBase<Object?>> customBoxes = {};

  @visibleForTesting
  bool isVaultStorageReady = false;

  @visibleForTesting
  bool isSecureEnvironment = true;

  Future<void>? _initFuture;

  /// Creates a new [VaultStorageImpl] instance.
  VaultStorageImpl({
    required ISecureKeyStore secureStorage,
    required IIdGenerator uuid,
    required IFileOperations fileOperations,
    VaultSecurityConfig? securityConfig,
    List<BoxConfig>? customBoxes,
    String? storageDirectory,
    VaultStorageConfig config = const VaultStorageConfig(),
  }) : _secureStorage = secureStorage,
       _uuid = uuid,
       _fileOperations = fileOperations,
       _securityConfig = securityConfig,
       _customBoxConfigs = switch (customBoxes) {
         final configs? => configs,
         null => const <BoxConfig>[],
       },
       _storageDirectory = storageDirectory,
       _config = config;

  @override
  Future<void> init() {
    if (isVaultStorageReady) return .value();
    return _initFuture ??= _doInit();
  }

  @override
  Future<T?> get<T>(String key, {bool? isSecure, String? box}) async {
    _ensureInitialized();

    try {
      if (box != null) return await _getFromBoxBase<T>(_requireCustomBox(box), key);
      if (isSecure != null) return await getFromBox<T>(isSecure ? .secure : .normal, key);
      return await _findStoredValue<T>(key);
    } catch (e, stackTrace) {
      if (e is VaultStorageError) rethrow;
      Error.throwWithStackTrace(VaultStorageReadError('Failed to get "$key"', e), stackTrace);
    }
  }

  Future<T?> _findStoredValue<T>(String key) async {
    final foundBoxes = <String>[];
    T? result;

    final normalValue = await getFromBox<T>(.normal, key);
    if (normalValue != null) {
      foundBoxes.add(StoredFileKeys.normalLocation);
      result = normalValue;
    }

    final secureValue = await getFromBox<T>(.secure, key);
    if (secureValue != null) {
      foundBoxes.add(StoredFileKeys.secureLocation);
      result = secureValue;
    }

    final customEntries = customBoxes.entries.toList();
    final customValues = await mapWithConcurrency(
      customEntries,
      _customBoxReadConcurrency,
      (entry) => _getFromBoxBase<T>(entry.value, key),
    );
    for (final (index, entry) in customEntries.indexed) {
      final value = customValues[index];
      if (value != null) {
        foundBoxes.add(entry.key);
        result = value;
      }
    }

    if (foundBoxes.length > 1) throw _multiBoxMatch('Key', key, foundBoxes);

    return result;
  }

  @override
  Future<void> saveSecure<T>({required String key, required T value, String? box}) async {
    _ensureInitialized();
    _validateSecureEnvironment();

    try {
      if (box != null) {
        await _putInBoxBase(_requireCustomBox(box), key, value);
        return;
      }

      await setInBox(.secure, key, value);

      if (boxes[BoxType.normal] case final normalBox? when normalBox.containsKey(key)) {
        await normalBox.delete(key);
      }
    } catch (e, stackTrace) {
      if (e is VaultStorageError) rethrow;
      Error.throwWithStackTrace(
        VaultStorageWriteError('Failed to set secure "$key"', e),
        stackTrace,
      );
    }
  }

  @override
  Future<void> saveNormal<T>({required String key, required T value, String? box}) async {
    _ensureInitialized();

    try {
      if (box != null) {
        await _putInBoxBase(_requireCustomBox(box), key, value);
        return;
      }

      await setInBox(.normal, key, value);
    } catch (e, stackTrace) {
      if (e is VaultStorageError) rethrow;
      Error.throwWithStackTrace(
        VaultStorageWriteError('Failed to set normal "$key"', e),
        stackTrace,
      );
    }
  }

  @override
  Future<void> delete(String key, {String? box}) async {
    _ensureInitialized();

    try {
      if (box != null) {
        await _deleteCustomKey(box, key);
        return;
      }

      await _deleteKeyFromBoxes(key, [.normal, .secure]);
    } catch (e, stackTrace) {
      if (e is VaultStorageError) rethrow;
      Error.throwWithStackTrace(VaultStorageDeleteError('Failed to delete "$key"', e), stackTrace);
    }
  }

  @override
  Future<void> clearNormal({bool includeFiles = false}) async {
    _ensureInitialized();

    try {
      await _requireBox(.normal).clear();
      if (includeFiles) {
        await clearAllFilesInBox(.normalFiles, isSecure: false);
      }
    } catch (e, stackTrace) {
      if (e is VaultStorageError) rethrow;
      Error.throwWithStackTrace(
        VaultStorageDeleteError('Failed to clear normal storage', e),
        stackTrace,
      );
    }
  }

  @override
  Future<void> clearSecure({bool includeFiles = false}) async {
    _ensureInitialized();
    _validateSecureEnvironment();

    try {
      await _requireBox(.secure).clear();
      if (includeFiles) {
        await clearAllFilesInBox(.secureFiles, isSecure: true);
      }
    } catch (e, stackTrace) {
      if (e is VaultStorageError) rethrow;
      Error.throwWithStackTrace(
        VaultStorageDeleteError('Failed to clear secure storage', e),
        stackTrace,
      );
    }
  }

  @override
  Future<void> clearAll({bool includeFiles = true}) async {
    _ensureInitialized();
    _validateSecureEnvironment();

    try {
      await Future.wait<void>([_requireBox(.normal).clear(), _requireBox(.secure).clear()]);

      await inOrder(
        customBoxes.values,
        (box) => box.clear(),
        reason: 'Custom boxes are cleared in the order they were opened',
      );

      if (!includeFiles) return;

      // File content goes first, then the metadata boxes
      await clearAllFilesInBox(.normalFiles, isSecure: false);
      await clearAllFilesInBox(.secureFiles, isSecure: true);

      // Delete the master encryption key since we're doing a complete wipe
      await _secureStorage.delete(key: StorageKeys.secureKey);
    } catch (e, stackTrace) {
      if (e is VaultStorageError) rethrow;
      Error.throwWithStackTrace(
        VaultStorageDeleteError('Failed to clear all storage', e),
        stackTrace,
      );
    }
  }

  @override
  Future<List<String>> keys({bool includeFiles = true, bool? isSecure}) async {
    _ensureInitialized();

    try {
      final List<BoxType> types = switch (isSecure) {
        true => [.secure, if (includeFiles) .secureFiles],
        false => [.normal, if (includeFiles) .normalFiles],
        null => [
          .normal,
          .secure,
          if (includeFiles) ...[.normalFiles, .secureFiles],
        ],
      };
      final result = <String>{
        for (final type in types) ..._stringKeys(boxes[type]),
        for (final box in customBoxes.values) ..._stringKeys(box),
      };

      return result.toList(growable: false)..sort();
    } catch (e, stackTrace) {
      Error.throwWithStackTrace(VaultStorageReadError('Failed to list keys', e), stackTrace);
    }
  }

  @override
  Future<void> saveSecureFile({
    required String key,
    required Uint8List fileBytes,
    String? originalFileName,
    Map<String, dynamic>? metadata,
    String? box,
  }) async {
    _ensureInitialized();
    _validateSecureEnvironment();

    try {
      final upload = _FileUpload(
        key: key,
        fileBytes: fileBytes,
        originalFileName: originalFileName,
        metadata: metadata,
      );
      if (box != null) {
        await _saveFileToCustomBox(box, upload);
        return;
      }

      final fileMetadata = await _storeSecureFileBytes(fileBytes, upload.extension);

      // Stored through _putInBoxBase for binary TypeAdapter encoding (v4.x)
      await _putInBoxBase(
        _requireBox(.secureFiles),
        key,
        upload.tagged(fileMetadata, isSecure: true),
      );
    } catch (e, stackTrace) {
      if (e is VaultStorageError) rethrow;
      Error.throwWithStackTrace(
        VaultStorageWriteError('Failed to save secure file "$key"', e),
        stackTrace,
      );
    }
  }

  @override
  Future<void> saveNormalFile({
    required String key,
    required Uint8List fileBytes,
    String? originalFileName,
    Map<String, dynamic>? metadata,
    String? box,
  }) async {
    _ensureInitialized();

    try {
      final upload = _FileUpload(
        key: key,
        fileBytes: fileBytes,
        originalFileName: originalFileName,
        metadata: metadata,
      );
      if (box != null) {
        await _saveFileToCustomBox(box, upload);
        return;
      }

      final fileMetadata = await _fileOperations.saveNormalFile(
        NormalFileRequest(
          fileBytes: fileBytes,
          fileExtension: upload.extension,
          services: _fileServices,
        ),
      );

      // Stored through _putInBoxBase for binary TypeAdapter encoding (v4.x)
      await _putInBoxBase(
        _requireBox(.normalFiles),
        key,
        upload.tagged(fileMetadata, isSecure: false),
      );
    } catch (e, stackTrace) {
      if (e is VaultStorageError) rethrow;
      Error.throwWithStackTrace(
        VaultStorageWriteError('Failed to save normal file "$key"', e),
        stackTrace,
      );
    }
  }

  @override
  Future<Uint8List?> getFile(String key, {bool? isSecure, String? box}) async {
    _ensureInitialized();

    try {
      if (box != null) return await _getCustomFile(box, key);
      if (isSecure != null) {
        final metadata = await getFileMetadata(key, isSecure: isSecure);
        return metadata.isEmpty ? null : await _readFileContent(metadata);
      }

      return await _findFileContent(key);
    } catch (e, stackTrace) {
      if (e is VaultStorageError) rethrow;
      Error.throwWithStackTrace(VaultStorageReadError('Failed to get file "$key"', e), stackTrace);
    }
  }

  @override
  Future<void> deleteFile(String key, {String? box}) async {
    _ensureInitialized();

    try {
      if (box != null) {
        await _deleteCustomKey(box, key);
        return;
      }

      final [normalMetadata, secureMetadata] = await Future.wait([
        getFileMetadata(key, isSecure: false),
        getFileMetadata(key, isSecure: true),
      ]);

      // Delete underlying file data first (avoid orphaned content/keys)
      if (normalMetadata.isNotEmpty) {
        await _fileOperations.deleteNormalFile(
          fileMetadata: normalMetadata,
          isWeb: kIsWeb,
          getBox: getInternalBox,
        );
      }

      if (secureMetadata.isNotEmpty) {
        await _fileOperations.deleteSecureFile(
          fileMetadata: secureMetadata,
          isWeb: kIsWeb,
          secureStorage: _secureStorage,
          getBox: getInternalBox,
        );
      }

      await _deleteKeyFromBoxes(key, [.normalFiles, .secureFiles]);
    } catch (e, stackTrace) {
      if (e is VaultStorageError) rethrow;
      Error.throwWithStackTrace(
        VaultStorageDeleteError('Failed to delete file "$key"', e),
        stackTrace,
      );
    }
  }

  Future<void> _deleteCustomKey(String box, String key) async {
    final customBox = _requireCustomBox(box);
    if (customBox.containsKey(key)) await customBox.delete(key);
  }

  Future<void> _deleteKeyFromBoxes(String key, List<BoxType> boxTypes) async {
    final candidates = <BoxBase<Object?>>[
      for (final type in boxTypes)
        if (boxes[type] case final box?) box,
      ...customBoxes.values,
    ];
    await Future.wait([
      for (final box in candidates)
        if (box.containsKey(key)) box.delete(key),
    ]);
  }

  @override
  Future<void> dispose() async {
    try {
      // Wait for any in-flight init to complete before tearing down
      final pending = _initFuture;
      _initFuture = null;
      if (pending != null) await _completes(() => pending);

      if (isVaultStorageReady) {
        // Close only the boxes opened by this service to avoid affecting other Hive users
        await inOrder(
          [...boxes.values, ...customBoxes.values],
          (box) => _completes(box.close),
          reason: 'Boxes are closed in the order they were opened',
        );
        boxes.clear();
        customBoxes.clear();

        isVaultStorageReady = false;
        isSecureEnvironment = true;
        _initFuture = null;
      }
    } catch (e, stackTrace) {
      Error.throwWithStackTrace(
        VaultStorageDisposalError('Failed to dispose vault storage', e),
        stackTrace,
      );
    }
  }

  void _ensureInitialized() {
    if (!isVaultStorageReady) {
      throw const VaultStorageInitializationError('Storage not initialized. Call init() first.');
    }
  }

  /// Validates custom box configs for reserved names and duplicates.
  @visibleForTesting
  static void validateCustomBoxConfigs(List<BoxConfig> configs) {
    const reservedNames = {
      StorageKeys.secureBox,
      StorageKeys.normalBox,
      StorageKeys.secureFilesBox,
      StorageKeys.normalFilesBox,
    };
    for (final config in configs) {
      if (reservedNames.contains(config.name)) {
        throw VaultStorageInitializationError(
          'Custom box name "${config.name}" conflicts with a reserved box name',
        );
      }
    }

    final seen = <String>{};
    for (final config in configs) {
      if (!seen.add(config.name)) {
        throw VaultStorageInitializationError(
          'Duplicate custom box name "${config.name}". Each box must have a unique name.',
        );
      }
    }
  }
}
