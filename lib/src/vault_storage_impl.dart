import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:vault_storage/src/constants/config.dart';
import 'package:vault_storage/src/constants/storage_keys.dart';
import 'package:vault_storage/src/entities/box_config.dart';
import 'package:vault_storage/src/enum/storage_box_type.dart';
import 'package:vault_storage/src/errors/errors.dart';
import 'package:vault_storage/src/extensions/extensions.dart';
import 'package:vault_storage/src/interface/i_file_operations.dart';
import 'package:vault_storage/src/interface/i_vault_storage.dart';
import 'package:vault_storage/src/mock/freerasp_mock.dart'
    if (dart.library.io) 'package:freerasp/freerasp.dart';
import 'package:vault_storage/src/security/security_exceptions.dart';
import 'package:vault_storage/src/security/vault_security_config.dart';
import 'package:vault_storage/src/storage/file_operations.dart';
import 'package:vault_storage/src/storage/storage_strategy.dart';
import 'package:vault_storage/src/storage/vault_storage_adapter_registry.dart';

part 'vault_storage_impl_helpers.dart';

/// Simple, secure storage implementation for Flutter apps.
///
/// Provides key-value and file storage with automatic encryption for secure data.
/// Uses performance-optimized search order (normal storage first, then secure storage).
class VaultStorageImpl implements IVaultStorage {
  final FlutterSecureStorage _secureStorage;
  final Uuid _uuid;
  final IFileOperations _fileOperations;
  final VaultSecurityConfig? _securityConfig;
  final List<BoxConfig>? _customBoxConfigs;
  final String? _storageDirectory;

  @visibleForTesting
  final Map<BoxType, BoxBase<dynamic>> boxes = {};

  @visibleForTesting
  final Map<String, BoxBase<dynamic>> customBoxes = {};

  @visibleForTesting
  bool isVaultStorageReady = false;

  @visibleForTesting
  bool isSecureEnvironment = true;

  Future<void>? _initFuture;

  /// Creates a new [VaultStorageImpl] instance.
  VaultStorageImpl({
    FlutterSecureStorage? secureStorage,
    Uuid? uuid,
    IFileOperations? fileOperations,
    VaultSecurityConfig? securityConfig,
    List<BoxConfig>? customBoxes,
    String? storageDirectory,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _uuid = uuid ?? const Uuid(),
       _fileOperations = fileOperations ?? FileOperations(),
       _securityConfig = securityConfig,
       _customBoxConfigs = customBoxes,
       _storageDirectory = storageDirectory {
    _registerAdapters();
  }

  @override
  Future<void> init() {
    if (isVaultStorageReady) return Future<void>.value();
    return _initFuture ??= _doInit();
  }

  // ==========================================
  // KEY-VALUE STORAGE
  // ==========================================

  @override
  Future<T?> get<T>(String key, {bool? isSecure, String? box}) async {
    _ensureInitialized();

    try {
      // If a specific box is requested, only check that box
      if (box != null) {
        final customBox = customBoxes[box];
        if (customBox == null) {
          throw BoxNotFoundError('Box "$box" not found. Register it during init()');
        }
        return await _getFromBoxBase<T>(customBox, key);
      }

      // If isSecure is specified, use default boxes
      if (isSecure != null) {
        switch (isSecure) {
          case false:
            return await getFromBox<T>(BoxType.normal, key);
          case true:
            return await getFromBox<T>(BoxType.secure, key);
        }
      }

      // Search all boxes and detect ambiguity
      final foundBoxes = <String>[];
      T? result;

      // Check default normal box
      final normalValue = await getFromBox<T>(BoxType.normal, key);
      if (normalValue != null) {
        foundBoxes.add('normal');
        result = normalValue;
      }

      // Check default secure box
      final secureValue = await getFromBox<T>(BoxType.secure, key);
      if (secureValue != null) {
        foundBoxes.add('secure');
        result = secureValue;
      }

      // Check custom boxes
      for (final entry in customBoxes.entries) {
        final value = await _getFromBoxBase<T>(entry.value, key);
        if (value != null) {
          foundBoxes.add(entry.key);
          result = value;
        }
      }

      // If found in multiple boxes, throw ambiguity error
      if (foundBoxes.length > 1) {
        throw AmbiguousKeyError(
          key,
          foundBoxes,
          'Key "$key" found in multiple boxes: ${foundBoxes.join(", ")}. '
          'Specify the box parameter to disambiguate.',
        );
      }

      return result;
    } catch (e) {
      if (e is VaultStorageError) rethrow;
      throw VaultStorageReadError('Failed to get "$key"', e);
    }
  }

  @override
  Future<void> saveSecure<T>({required String key, required T value, String? box}) async {
    _ensureInitialized();
    _validateSecureEnvironment();

    try {
      // If box specified, use custom box (encryption determined by box config)
      if (box != null) {
        final customBox = customBoxes[box];
        if (customBox == null) {
          throw BoxNotFoundError('Box "$box" not found. Register it during init()');
        }
        await _putInBoxBase(customBox, key, value);
        return;
      }

      // Default: use secure box
      await setInBox(BoxType.secure, key, value);

      // Optional: Remove from normal box if it exists there
      final normalBox = boxes[BoxType.normal];
      if (normalBox?.containsKey(key) == true) {
        await normalBox!.delete(key);
      }
    } catch (e) {
      if (e is VaultStorageError) rethrow;
      throw VaultStorageWriteError('Failed to set secure "$key"', e);
    }
  }

  @override
  Future<void> saveNormal<T>({required String key, required T value, String? box}) async {
    _ensureInitialized();

    try {
      // If box specified, use custom box (encryption determined by box config)
      if (box != null) {
        final customBox = customBoxes[box];
        if (customBox == null) {
          throw BoxNotFoundError('Box "$box" not found. Register it during init()');
        }
        await _putInBoxBase(customBox, key, value);
        return;
      }

      // Default: use normal box
      await setInBox(BoxType.normal, key, value);
    } catch (e) {
      if (e is VaultStorageError) rethrow;
      throw VaultStorageWriteError('Failed to set normal "$key"', e);
    }
  }

  @override
  Future<void> delete(String key, {String? box}) async {
    _ensureInitialized();

    try {
      // If box specified, delete from custom box only
      if (box != null) {
        await _deleteCustomKey(box, key);
        return;
      }

      await _deleteKeyFromBoxes(key, [BoxType.normal, BoxType.secure]);
    } catch (e) {
      if (e is VaultStorageError) rethrow;
      throw VaultStorageDeleteError('Failed to delete "$key"', e);
    }
  }

  @override
  Future<void> clearNormal({bool includeFiles = false}) async {
    _ensureInitialized();

    try {
      await boxes[BoxType.normal]!.clear();
      if (includeFiles) {
        await clearAllFilesInBox(BoxType.normalFiles, isSecure: false);
      }
    } catch (e) {
      if (e is VaultStorageError) rethrow;
      throw VaultStorageDeleteError('Failed to clear normal storage', e);
    }
  }

  @override
  Future<void> clearSecure({bool includeFiles = false}) async {
    _ensureInitialized();
    _validateSecureEnvironment();

    try {
      await boxes[BoxType.secure]!.clear();
      if (includeFiles) {
        await clearAllFilesInBox(BoxType.secureFiles, isSecure: true);
      }
    } catch (e) {
      if (e is VaultStorageError) rethrow;
      throw VaultStorageDeleteError('Failed to clear secure storage', e);
    }
  }

  @override
  Future<void> clearAll({bool includeFiles = true}) async {
    _ensureInitialized();
    _validateSecureEnvironment();

    try {
      // 1) Clear key-value stores
      await Future.wait<void>([boxes[BoxType.normal]!.clear(), boxes[BoxType.secure]!.clear()]);

      // 2) Always clear custom boxes (they hold key-value data)
      for (final box in customBoxes.values) {
        await box.clear();
      }

      if (!includeFiles) return;

      // 3) For files, delete underlying file content first, then clear metadata boxes
      await clearAllFilesInBox(BoxType.normalFiles, isSecure: false);
      await clearAllFilesInBox(BoxType.secureFiles, isSecure: true);

      // 4) Delete the master encryption key since we're doing a complete wipe
      await _secureStorage.delete(key: StorageKeys.secureKey);
    } catch (e) {
      if (e is VaultStorageError) rethrow;
      throw VaultStorageDeleteError('Failed to clear all storage', e);
    }
  }

  @override
  Future<List<String>> keys({bool includeFiles = true, bool? isSecure}) async {
    _ensureInitialized();

    try {
      final result = <String>{};

      // Helper to collect keys from a box (both Box and LazyBox expose keys)
      void collect(BoxType type) {
        final box = boxes[type];
        if (box != null) {
          result.addAll(box.keys.whereType<String>());
        }
      }

      switch (isSecure) {
        case true:
          collect(BoxType.secure);
          if (includeFiles) collect(BoxType.secureFiles);
        case false:
          collect(BoxType.normal);
          if (includeFiles) collect(BoxType.normalFiles);
        case null:
          collect(BoxType.normal);
          collect(BoxType.secure);
          if (includeFiles) {
            collect(BoxType.normalFiles);
            collect(BoxType.secureFiles);
          }
      }

      // Collect from custom boxes
      for (final entry in customBoxes.entries) {
        result.addAll(entry.value.keys.whereType<String>());
      }

      return result.toList(growable: false)..sort();
    } catch (e) {
      throw VaultStorageReadError('Failed to list keys', e);
    }
  }

  // ==========================================
  // FILE STORAGE
  // ==========================================

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
      // If box specified, use custom box (encryption determined by box config)
      if (box != null) {
        await _saveFileToCustomBox(
          box: box,
          key: key,
          fileBytes: fileBytes,
          originalFileName: originalFileName,
          metadata: metadata,
        );
        return;
      }

      // Default secure file storage logic
      final ext = originalFileName?.split('.').last ?? 'bin';
      final shouldStream = fileBytes.length >= VaultStorageConfig.secureFileStreamingThresholdBytes;

      final fileMetadata = shouldStream
          ? await _fileOperations.saveSecureFileStream(
              stream: Stream<List<int>>.value(fileBytes),
              fileExtension: ext,
              isWeb: kIsWeb,
              secureStorage: _secureStorage,
              uuid: _uuid,
              getBox: getInternalBox,
              chunkSize: VaultStorageConfig.secureFileStreamingChunkSizeBytes,
            )
          : await _fileOperations.saveSecureFile(
              fileBytes: fileBytes,
              fileExtension: ext,
              isWeb: kIsWeb,
              secureStorage: _secureStorage,
              uuid: _uuid,
              getBox: getInternalBox,
            );

      // Tag the metadata as secure and merge any user-provided metadata
      final toStore = <String, dynamic>{
        ...fileMetadata,
        'isSecure': true,
        if (metadata != null) 'userMetadata': metadata,
      };

      // Store the metadata using _putInBoxBase so it benefits from binary
      // TypeAdapter encoding (v4.x) rather than JSON string serialisation.
      await _putInBoxBase(boxes[BoxType.secureFiles]!, key, toStore);
    } catch (e) {
      if (e is VaultStorageError) rethrow;
      throw VaultStorageWriteError('Failed to save secure file "$key"', e);
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
      // If box specified, use custom box (encryption determined by box config)
      if (box != null) {
        await _saveFileToCustomBox(
          box: box,
          key: key,
          fileBytes: fileBytes,
          originalFileName: originalFileName,
          metadata: metadata,
        );
        return;
      }

      // Default normal file storage logic
      final fileMetadata = await _fileOperations.saveNormalFile(
        fileBytes: fileBytes,
        fileExtension: originalFileName?.split('.').last ?? 'bin',
        isWeb: kIsWeb,
        uuid: _uuid,
        getBox: getInternalBox,
      );

      // Tag the metadata as non-secure and merge any user-provided metadata
      final toStore = <String, dynamic>{
        ...fileMetadata,
        'isSecure': false,
        if (metadata != null) 'userMetadata': metadata,
      };

      // Store the metadata using _putInBoxBase so it benefits from binary
      // TypeAdapter encoding (v4.x) rather than JSON string serialisation.
      await _putInBoxBase(boxes[BoxType.normalFiles]!, key, toStore);
    } catch (e) {
      if (e is VaultStorageError) rethrow;
      throw VaultStorageWriteError('Failed to save normal file "$key"', e);
    }
  }

  // Note: streaming is handled internally based on threshold above

  @override
  Future<Uint8List?> getFile(String key, {bool? isSecure, String? box}) async {
    _ensureInitialized();

    try {
      if (box != null) {
        return await _getCustomFile(box, key);
      }
      if (isSecure != null) {
        final metadata = await getFileMetadata(key, isSecure: isSecure);
        return metadata == null ? null : await _readFileContent(metadata);
      }

      final match = await _findFile(key);
      if (match.locations.length > 1) {
        throw AmbiguousKeyError(
          key,
          match.locations,
          'File key "$key" found in multiple boxes: ${match.locations.join(", ")}. '
          'Specify the box parameter to disambiguate.',
        );
      }
      if (match.customBase64 != null) return await _decodeCustomFile(match.customBase64!);
      if (match.metadata != null) return await _readFileContent(match.metadata!);
      return null;
    } catch (e) {
      if (e is VaultStorageError) rethrow;
      throw VaultStorageReadError('Failed to get file "$key"', e);
    }
  }

  Future<Uint8List?> _getCustomFile(String box, String key) async {
    final metadata = await _getFromBoxBase<Map<String, dynamic>>(_requireCustomBox(box), key);
    if (metadata == null) return null;
    final encoded = metadata['base64Data'];
    if (metadata['isCustomBox'] != true || encoded is! String) {
      throw VaultStorageReadError('Invalid custom box file metadata for "$key"');
    }
    return _decodeCustomFile(encoded);
  }

  Future<Uint8List> _decodeCustomFile(String encoded) =>
      encoded.decodeBase64Safely(context: 'custom box file');

  Future<Uint8List> _readFileContent(Map<String, dynamic> metadata) {
    if (metadata['isSecure'] as bool? ?? false) {
      return _fileOperations.getSecureFile(
        fileMetadata: metadata,
        isWeb: kIsWeb,
        secureStorage: _secureStorage,
        getBox: getInternalBox,
      );
    }
    return _fileOperations.getNormalFile(
      fileMetadata: metadata,
      isWeb: kIsWeb,
      getBox: getInternalBox,
    );
  }

  Future<_FileMatch> _findFile(String key) async {
    final match = _FileMatch();
    final normalMetadata = await getFileMetadata(key, isSecure: false);
    if (normalMetadata != null) {
      match
        ..locations.add('normal_files')
        ..metadata = normalMetadata;
    }
    final secureMetadata = await getFileMetadata(key, isSecure: true);
    if (secureMetadata != null) {
      match
        ..locations.add('secure_files')
        ..metadata = secureMetadata;
    }
    for (final entry in customBoxes.entries) {
      final metadata = await _getFromBoxBase<Map<String, dynamic>>(entry.value, key);
      if (metadata?['isCustomBox'] == true) {
        match
          ..locations.add(entry.key)
          ..customBase64 = metadata!['base64Data'] as String;
      }
    }
    return match;
  }

  @override
  Future<void> deleteFile(String key, {String? box}) async {
    _ensureInitialized();

    try {
      // If box specified, delete from custom box only
      if (box != null) {
        await _deleteCustomKey(box, key);
        return;
      }

      // Delete from all boxes
      // Fetch metadata for normal and secure files if present
      final normalMetadata = await getFileMetadata(key, isSecure: false);
      final secureMetadata = await getFileMetadata(key, isSecure: true);

      // Delete underlying file data first (avoid orphaned content/keys)
      if (normalMetadata != null) {
        await _fileOperations.deleteNormalFile(
          fileMetadata: normalMetadata,
          isWeb: kIsWeb,
          getBox: getInternalBox,
        );
      }

      if (secureMetadata != null) {
        await _fileOperations.deleteSecureFile(
          fileMetadata: secureMetadata,
          isWeb: kIsWeb,
          secureStorage: _secureStorage,
          getBox: getInternalBox,
        );
      }

      await _deleteKeyFromBoxes(key, [BoxType.normalFiles, BoxType.secureFiles]);
    } catch (e) {
      if (e is VaultStorageError) rethrow;
      throw VaultStorageDeleteError('Failed to delete file "$key"', e);
    }
  }

  BoxBase<dynamic> _requireCustomBox(String name) {
    final box = customBoxes[name];
    if (box == null) {
      throw BoxNotFoundError('Box "$name" not found. Register it during init()');
    }
    return box;
  }

  Future<void> _saveFileToCustomBox({
    required String box,
    required String key,
    required Uint8List fileBytes,
    required String? originalFileName,
    required Map<String, dynamic>? metadata,
  }) async {
    final toStore = <String, dynamic>{
      'base64Data': await fileBytes.encodeBase64Safely(context: 'custom box file'),
      'extension': originalFileName?.split('.').last ?? 'bin',
      'isCustomBox': true,
      if (metadata != null) 'userMetadata': metadata,
    };
    await _putInBoxBase(_requireCustomBox(box), key, toStore);
  }

  Future<void> _deleteCustomKey(String box, String key) async {
    final customBox = _requireCustomBox(box);
    if (customBox.containsKey(key)) await customBox.delete(key);
  }

  Future<void> _deleteKeyFromBoxes(String key, List<BoxType> boxTypes) async {
    final candidates = <BoxBase<dynamic>>[
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
      if (pending != null) {
        try {
          await pending;
        } catch (_) {
          // Init failed — nothing to clean up
        }
      }

      if (isVaultStorageReady) {
        // Close only the boxes opened by this service to avoid affecting other Hive users
        for (final box in boxes.values) {
          try {
            await box.close();
          } catch (_) {
            // Ignore close errors during disposal
          }
        }
        boxes.clear();

        // Close custom boxes
        for (final box in customBoxes.values) {
          try {
            await box.close();
          } catch (_) {
            // Ignore close errors during disposal
          }
        }
        customBoxes.clear();

        isVaultStorageReady = false;
        isSecureEnvironment = true;
        _initFuture = null;
      }
    } catch (e) {
      throw VaultStorageDisposalError('Failed to dispose vault storage', e);
    }
  }

  // ==========================================
  // PRIVATE HELPER METHODS
  // ==========================================

  /// Ensure storage is initialized
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

class _FileMatch {
  final locations = <String>[];
  Map<String, dynamic>? metadata;
  String? customBase64;
}
