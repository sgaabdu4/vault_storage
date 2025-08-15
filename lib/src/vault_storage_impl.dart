import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:vault_storage/src/constants/config.dart';
import 'package:vault_storage/src/constants/storage_keys.dart';
import 'package:vault_storage/src/enum/storage_box_type.dart';
import 'package:vault_storage/src/errors/errors.dart';
import 'package:vault_storage/src/extensions/extensions.dart';
import 'package:vault_storage/src/interface/i_file_operations.dart';
import 'package:vault_storage/src/interface/i_vault_storage.dart';
import 'package:vault_storage/src/storage/file_operations.dart';

/// Simple, secure storage implementation for Flutter apps.
///
/// Provides key-value and file storage with automatic encryption for secure data.
/// Uses performance-optimized search order (normal storage first, then secure storage).
class VaultStorageImpl implements IVaultStorage {
  final FlutterSecureStorage _secureStorage;
  final Uuid _uuid;
  final IFileOperations _fileOperations;

  @visibleForTesting
  final Map<BoxType, BoxBase<dynamic>> boxes = {};

  @visibleForTesting
  bool isVaultStorageReady = false;

  /// Creates a new [VaultStorageImpl] instance.
  VaultStorageImpl({
    FlutterSecureStorage? secureStorage,
    Uuid? uuid,
    IFileOperations? fileOperations,
  })  : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _uuid = uuid ?? const Uuid(),
        _fileOperations = fileOperations ?? FileOperations();

  @override
  Future<void> init() async {
    if (isVaultStorageReady) return;

    try {
      await Hive.initFlutter();
      final key = await getOrCreateSecureKey();
      await openBoxes(key);
      isVaultStorageReady = true;
    } catch (e) {
      throw StorageInitializationError('Failed to initialize vault storage', e);
    }
  }

  // ==========================================
  // KEY-VALUE STORAGE
  // ==========================================

  @override
  Future<T?> get<T>(String key, {bool? isSecure}) async {
    _ensureInitialized();

    try {
      switch (isSecure) {
        case false:
          // Only check normal storage
          return await getFromBox<T>(BoxType.normal, key);
        case true:
          // Only check secure storage
          return await getFromBox<T>(BoxType.secure, key);
        case null:
          // Check both: normal first (performance), then secure
          final normalValue = await getFromBox<T>(BoxType.normal, key);
          if (normalValue != null) return normalValue;
          return await getFromBox<T>(BoxType.secure, key);
      }
    } catch (e) {
      throw StorageReadError('Failed to get "$key"', e);
    }
  }

  @override
  Future<void> saveSecure<T>({required String key, required T value}) async {
    _ensureInitialized();

    try {
      await setInBox(BoxType.secure, key, value);

      // Optional: Remove from normal box if it exists there
      final normalBox = boxes[BoxType.normal];
      if (normalBox?.containsKey(key) == true) {
        await normalBox!.delete(key);
      }
    } catch (e) {
      throw StorageWriteError('Failed to set secure "$key"', e);
    }
  }

  @override
  Future<void> saveNormal<T>({required String key, required T value}) async {
    _ensureInitialized();

    try {
      await setInBox(BoxType.normal, key, value);
    } catch (e) {
      throw StorageWriteError('Failed to set normal "$key"', e);
    }
  }

  @override
  Future<void> delete(String key) async {
    _ensureInitialized();

    try {
      // Delete from both key-value boxes
      await Future.wait<void>([
        if (boxes[BoxType.normal]?.containsKey(key) == true) boxes[BoxType.normal]!.delete(key),
        if (boxes[BoxType.secure]?.containsKey(key) == true) boxes[BoxType.secure]!.delete(key),
      ]);
    } catch (e) {
      throw StorageDeleteError('Failed to delete "$key"', e);
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
      throw StorageDeleteError('Failed to clear normal storage', e);
    }
  }

  @override
  Future<void> clearSecure({bool includeFiles = false}) async {
    _ensureInitialized();

    try {
      await boxes[BoxType.secure]!.clear();
      if (includeFiles) {
        await clearAllFilesInBox(BoxType.secureFiles, isSecure: true);
      }
    } catch (e) {
      throw StorageDeleteError('Failed to clear secure storage', e);
    }
  }

  @override
  Future<void> clearAll({bool includeFiles = true}) async {
    _ensureInitialized();

    try {
      // 1) Clear key-value stores
      await Future.wait<void>([
        boxes[BoxType.normal]!.clear(),
        boxes[BoxType.secure]!.clear(),
      ]);

      if (!includeFiles) return;

      // 2) For files, delete underlying file content first, then clear metadata boxes
      await clearAllFilesInBox(BoxType.normalFiles, isSecure: false);
      await clearAllFilesInBox(BoxType.secureFiles, isSecure: true);
    } catch (e) {
      throw StorageDeleteError('Failed to clear all storage', e);
    }
  }

  @override
  Future<List<String>> keys({bool includeFiles = true, bool? isSecure}) async {
    _ensureInitialized();

    try {
      final result = <String>{};

      // Helper to collect keys from a box
      Future<void> collect(BoxType type) async {
        final box = boxes[type];
        if (box == null) return;
        if (box is Box) {
          result.addAll(box.keys.whereType<String>());
        } else if (box is LazyBox) {
          // LazyBox exposes keys via keys property (sync) in Hive_ce
          result.addAll(box.keys.whereType<String>());
        }
      }

      switch (isSecure) {
        case true:
          await collect(BoxType.secure);
          if (includeFiles) await collect(BoxType.secureFiles);
        case false:
          await collect(BoxType.normal);
          if (includeFiles) await collect(BoxType.normalFiles);
        case null:
          await collect(BoxType.normal);
          await collect(BoxType.secure);
          if (includeFiles) {
            await collect(BoxType.normalFiles);
            await collect(BoxType.secureFiles);
          }
      }

      return result.toList(growable: false)..sort();
    } catch (e) {
      throw StorageReadError('Failed to list keys', e);
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
  }) async {
    _ensureInitialized();

    try {
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

      // Store the metadata with the user's key - serialize to JSON
      final jsonString = await toStore.encodeJsonSafely();

      await boxes[BoxType.secureFiles]!.put(key, jsonString);
    } catch (e) {
      if (e is StorageError) rethrow;
      throw StorageWriteError('Failed to save secure file "$key"', e);
    }
  }

  @override
  Future<void> saveNormalFile({
    required String key,
    required Uint8List fileBytes,
    String? originalFileName,
    Map<String, dynamic>? metadata,
  }) async {
    _ensureInitialized();

    try {
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

      // Store the metadata with the user's key - serialize to JSON
      final jsonString = await toStore.encodeJsonSafely();

      await boxes[BoxType.normalFiles]!.put(key, jsonString);
    } catch (e) {
      if (e is StorageError) rethrow;
      throw StorageWriteError('Failed to save normal file "$key"', e);
    }
  }

  // Note: streaming is handled internally based on threshold above

  @override
  Future<Uint8List?> getFile(String key, {bool? isSecure}) async {
    _ensureInitialized();

    try {
      // First get file metadata to determine which box it's in
      final metadata = await getFileMetadata(key, isSecure: isSecure);
      if (metadata == null) return null;

      // Determine if this is a secure file based on returned metadata
      final isSecureFile = metadata['isSecure'] as bool? ?? false;

      if (isSecureFile) {
        return await _fileOperations.getSecureFile(
          fileMetadata: metadata,
          isWeb: kIsWeb,
          secureStorage: _secureStorage,
          getBox: getInternalBox,
        );
      } else {
        return await _fileOperations.getNormalFile(
          fileMetadata: metadata,
          isWeb: kIsWeb,
          getBox: getInternalBox,
        );
      }
    } catch (e) {
      if (e is StorageError) rethrow;
      throw StorageReadError('Failed to get file "$key"', e);
    }
  }

  @override
  Future<void> deleteFile(String key) async {
    _ensureInitialized();

    try {
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

      // Finally, remove the user-facing metadata entries from both boxes
      await Future.wait<void>([
        if (boxes[BoxType.normalFiles]?.containsKey(key) == true)
          boxes[BoxType.normalFiles]!.delete(key),
        if (boxes[BoxType.secureFiles]?.containsKey(key) == true)
          boxes[BoxType.secureFiles]!.delete(key),
      ]);
    } catch (e) {
      throw StorageDeleteError('Failed to delete file "$key"', e);
    }
  }

  @override
  Future<void> dispose() async {
    try {
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
        isVaultStorageReady = false;
      }
    } catch (e) {
      throw StorageDisposalError('Failed to dispose vault storage', e);
    }
  }

  // ==========================================
  // PRIVATE HELPER METHODS
  // ==========================================

  /// Ensure storage is initialized
  void _ensureInitialized() {
    if (!isVaultStorageReady) {
      throw const StorageInitializationError('Storage not initialized. Call init() first.');
    }
  }

  /// Get value from a specific box (supports both Box and LazyBox)
  @visibleForTesting
  Future<T?> getFromBox<T>(BoxType boxType, String key) async {
    final box = boxes[boxType];
    if (box == null) return null;

    String? jsonString;
    if (box is LazyBox<dynamic>) {
      // Handle lazy boxes (files) - asynchronous get, sync containsKey in Hive_ce
      if (!box.containsKey(key)) return null;
      jsonString = await box.get(key) as String?;
    } else if (box is Box<dynamic>) {
      // Handle normal boxes (key-value) - synchronous access but async decode
      if (!box.containsKey(key)) return null;
      jsonString = box.get(key) as String?;
    } else {
      return null;
    }

    if (jsonString == null) return null;
    return jsonString.decodeJsonSafely<T>();
  }

  /// Set value in a specific box
  @visibleForTesting
  Future<void> setInBox<T>(BoxType boxType, String key, T value) async {
    final box = boxes[boxType];
    if (box == null) {
      throw StorageInitializationError('Box ${boxType.name} not opened. Ensure init() was called.');
    }

    final jsonString = await value.encodeJsonSafely();

    if (box is LazyBox<dynamic>) {
      // Handle lazy boxes (files)
      await box.put(key, jsonString);
    } else if (box is Box<dynamic>) {
      // Handle normal boxes (key-value)
      await box.put(key, jsonString);
    } else {
      throw StorageWriteError('Unsupported box type for ${boxType.name}');
    }
  }

  /// Get file metadata with optional storage type specification
  @visibleForTesting
  Future<Map<String, dynamic>?> getFileMetadata(String key, {bool? isSecure}) async {
    switch (isSecure) {
      case false:
        final box = boxes[BoxType.normalFiles];
        if (box == null) return null;

        String? jsonString;
        if (box is LazyBox<dynamic>) {
          if (!box.containsKey(key)) return null;
          jsonString = await box.get(key) as String?;
        } else if (box is Box<dynamic>) {
          if (!box.containsKey(key)) return null;
          jsonString = box.get(key) as String?;
        }

        if (jsonString == null) return null;
        try {
          final result = await jsonString.decodeJsonSafely<Map<String, dynamic>>();
          // Explicitly tag source
          return <String, dynamic>{...result, 'isSecure': false};
        } catch (e) {
          return null;
        }
      case true:
        final box = boxes[BoxType.secureFiles];
        if (box == null) return null;

        String? jsonString;
        if (box is LazyBox<dynamic>) {
          if (!box.containsKey(key)) return null;
          jsonString = await box.get(key) as String?;
        } else if (box is Box<dynamic>) {
          if (!box.containsKey(key)) return null;
          jsonString = box.get(key) as String?;
        }

        if (jsonString == null) return null;
        try {
          final result = await jsonString.decodeJsonSafely<Map<String, dynamic>>();
          // Explicitly tag source
          return <String, dynamic>{...result, 'isSecure': true};
        } catch (e) {
          return null;
        }
      case null:
        // Check normal files first, then secure files
        final normalBox = boxes[BoxType.normalFiles];
        if (normalBox != null) {
          String? normalJsonString;
          if (normalBox is LazyBox<dynamic>) {
            if (normalBox.containsKey(key)) {
              normalJsonString = await normalBox.get(key) as String?;
            }
          } else if (normalBox is Box<dynamic>) {
            if (normalBox.containsKey(key)) {
              normalJsonString = normalBox.get(key) as String?;
            }
          }

          if (normalJsonString != null) {
            try {
              final normalMetadata =
                  await normalJsonString.decodeJsonSafely<Map<String, dynamic>>();
              return <String, dynamic>{...normalMetadata, 'isSecure': false};
            } catch (e) {
              // Continue to secure files
            }
          }
        }

        final secureBox = boxes[BoxType.secureFiles];
        if (secureBox != null) {
          String? secureJsonString;
          if (secureBox is LazyBox<dynamic>) {
            if (secureBox.containsKey(key)) {
              secureJsonString = await secureBox.get(key) as String?;
            }
          } else if (secureBox is Box<dynamic>) {
            if (secureBox.containsKey(key)) {
              secureJsonString = secureBox.get(key) as String?;
            }
          }

          if (secureJsonString != null) {
            try {
              final secureMetadata =
                  await secureJsonString.decodeJsonSafely<Map<String, dynamic>>();
              return <String, dynamic>{...secureMetadata, 'isSecure': true};
            } catch (e) {
              return null;
            }
          }
        }
        return null;
    }
  }

  /// Get a box from storage - returns the box directly
  @visibleForTesting
  BoxBase<dynamic> getInternalBox(BoxType type) {
    return boxes[type]!;
  }

  /// Clear all files (underlying content + metadata) within a specific files box.
  /// Best-effort: continues on per-item failures. Throws if box.clear() fails.
  @visibleForTesting
  Future<void> clearAllFilesInBox(BoxType boxType, {required bool isSecure}) async {
    final box = boxes[boxType];
    if (box == null) return;

    Iterable<dynamic> keyIterable;
    if (box is LazyBox) {
      keyIterable = box.keys;
    } else if (box is Box) {
      keyIterable = box.keys;
    } else {
      return;
    }

    for (final key in keyIterable.whereType<String>()) {
      try {
        final metadata = await getFileMetadata(key, isSecure: isSecure);
        if (metadata == null) continue;
        if (isSecure) {
          await _fileOperations.deleteSecureFile(
            fileMetadata: metadata,
            isWeb: kIsWeb,
            secureStorage: _secureStorage,
            getBox: getInternalBox,
          );
        } else {
          await _fileOperations.deleteNormalFile(
            fileMetadata: metadata,
            isWeb: kIsWeb,
            getBox: getInternalBox,
          );
        }
      } catch (_) {
        // Ignore per-file errors; final clear() will drop metadata
      }
    }

    await box.clear();
  }

  @visibleForTesting
  Future<List<int>> getOrCreateSecureKey() async {
    try {
      final encodedKey = await _secureStorage.read(key: StorageKeys.secureKey);

      if (encodedKey == null) {
        final key = Hive.generateSecureKey();
        await _secureStorage.write(key: StorageKeys.secureKey, value: key.encodeBase64());
        return key;
      }

      return encodedKey.decodeBase64Safely(context: 'secure storage key');
    } catch (e) {
      throw StorageInitializationError('Failed to get/create secure key', e);
    }
  }

  @visibleForTesting
  Future<void> openBoxes(List<int> encryptionKey) async {
    try {
      final cipher = HiveAesCipher(encryptionKey);

      // Custom compaction strategy - more aggressive for storage service
      bool vaultCompactionStrategy(int entries, int deletedEntries) {
        if (entries == 0) return false;
        const deletedRatio = 0.10; // 10% instead of default 15%
        const deletedThreshold = 30; // 30 instead of default 60
        return deletedEntries > deletedThreshold && deletedEntries / entries > deletedRatio;
      }

      // Open key-value storage boxes (normal boxes for fast access)
      boxes[BoxType.secure] = await Hive.openBox<String>(
        StorageKeys.secureBox,
        encryptionCipher: cipher,
        compactionStrategy: vaultCompactionStrategy,
      );
      boxes[BoxType.normal] = await Hive.openBox<String>(
        StorageKeys.normalBox,
        compactionStrategy: vaultCompactionStrategy,
      );

      // Open file storage boxes (lazy boxes for better memory usage)
      boxes[BoxType.secureFiles] = await Hive.openLazyBox<String>(
        StorageKeys.secureFilesBox,
        encryptionCipher: cipher,
        compactionStrategy: vaultCompactionStrategy,
      );
      boxes[BoxType.normalFiles] = await Hive.openLazyBox<String>(
        StorageKeys.normalFilesBox,
        compactionStrategy: vaultCompactionStrategy,
      );
    } catch (e) {
      throw StorageInitializationError('Failed to open storage boxes', e);
    }
  }
}
