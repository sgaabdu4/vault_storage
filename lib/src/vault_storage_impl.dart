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

  /// Creates a new [VaultStorageImpl] instance.
  VaultStorageImpl({
    FlutterSecureStorage? secureStorage,
    Uuid? uuid,
    IFileOperations? fileOperations,
    VaultSecurityConfig? securityConfig,
    List<BoxConfig>? customBoxes,
    String? storageDirectory,
  })  : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _uuid = uuid ?? const Uuid(),
        _fileOperations = fileOperations ?? FileOperations(),
        _securityConfig = securityConfig,
        _customBoxConfigs = customBoxes,
        _storageDirectory = storageDirectory;

  @override
  Future<void> init() async {
    if (isVaultStorageReady) return;

    try {
      // Initialize RASP protection first if enabled and on supported platforms
      if (_securityConfig?.enableRaspProtection == true) {
        // FreeRASP only supports Android and iOS
        if (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS) {
          await _initializeRaspProtection(
            packageName: _securityConfig?.androidPackageName,
            signingCertHashes: _securityConfig?.androidSigningCertHashes,
            bundleId: _securityConfig?.iosBundleId,
            teamId: _securityConfig?.iosTeamId,
          );
        } else {
          // Log that security features are not available on this platform
          if (_securityConfig?.enableLogging == true) {
            debugPrint(
                'VaultStorage: FreeRASP security features are only available on Android and iOS. '
                'Current platform: ${defaultTargetPlatform.name}');
          }
        }
      }

      await Hive.initFlutter(_storageDirectory);
      final key = await getOrCreateSecureKey();
      await openBoxes(key);

      // Open custom boxes if provided
      if (_customBoxConfigs != null && _customBoxConfigs!.isNotEmpty) {
        await _openCustomBoxes(_customBoxConfigs!, key);
      }

      isVaultStorageReady = true;
    } catch (e) {
      throw StorageInitializationError('Failed to initialize vault storage', e);
    }
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
      if (e is StorageError) rethrow;
      throw StorageReadError('Failed to get "$key"', e);
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
      if (e is StorageError) rethrow;
      throw StorageWriteError('Failed to set secure "$key"', e);
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
      if (e is StorageError) rethrow;
      throw StorageWriteError('Failed to set normal "$key"', e);
    }
  }

  @override
  Future<void> delete(String key, {String? box}) async {
    _ensureInitialized();

    try {
      // If box specified, delete from custom box only
      if (box != null) {
        final customBox = customBoxes[box];
        if (customBox == null) {
          throw BoxNotFoundError('Box "$box" not found. Register it during init()');
        }
        if (customBox.containsKey(key)) {
          await customBox.delete(key);
        }
        return;
      }

      // Delete from all boxes
      final deleteFutures = <Future<void>>[
        if (boxes[BoxType.normal]?.containsKey(key) == true) boxes[BoxType.normal]!.delete(key),
        if (boxes[BoxType.secure]?.containsKey(key) == true) boxes[BoxType.secure]!.delete(key),
      ];

      // Delete from custom boxes
      for (final entry in customBoxes.entries) {
        if (entry.value.containsKey(key)) {
          deleteFutures.add(entry.value.delete(key));
        }
      }

      await Future.wait<void>(deleteFutures);
    } catch (e) {
      if (e is StorageError) rethrow;
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

      // 3) Delete the master encryption key since we're doing a complete wipe
      await _secureStorage.delete(key: StorageKeys.secureKey);
    } catch (e) {
      throw StorageDeleteError('Failed to clear all storage', e);
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
    String? box,
  }) async {
    _ensureInitialized();

    try {
      // If box specified, use custom box (encryption determined by box config)
      if (box != null) {
        final customBox = customBoxes[box];
        if (customBox == null) {
          throw BoxNotFoundError('Box "$box" not found. Register it during init()');
        }

        // For custom boxes, store the file bytes directly as base64 in metadata
        // (simpler approach for custom boxes - no file_operations complexity)
        final base64Data = await fileBytes.encodeBase64Safely(context: 'custom box file');
        final toStore = <String, dynamic>{
          'base64Data': base64Data,
          'extension': originalFileName?.split('.').last ?? 'bin',
          'isCustomBox': true,
          if (metadata != null) 'userMetadata': metadata,
        };
        await _putInBoxBase(customBox, key, toStore);
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
    String? box,
  }) async {
    _ensureInitialized();

    try {
      // If box specified, use custom box (encryption determined by box config)
      if (box != null) {
        final customBox = customBoxes[box];
        if (customBox == null) {
          throw BoxNotFoundError('Box "$box" not found. Register it during init()');
        }

        // For custom boxes, store the file bytes directly as base64 in metadata
        final base64Data = await fileBytes.encodeBase64Safely(context: 'custom box file');
        final toStore = <String, dynamic>{
          'base64Data': base64Data,
          'extension': originalFileName?.split('.').last ?? 'bin',
          'isCustomBox': true,
          if (metadata != null) 'userMetadata': metadata,
        };
        await _putInBoxBase(customBox, key, toStore);
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
  Future<Uint8List?> getFile(String key, {bool? isSecure, String? box}) async {
    _ensureInitialized();

    try {
      // If box specified, get from custom box only
      if (box != null) {
        final customBox = customBoxes[box];
        if (customBox == null) {
          throw BoxNotFoundError('Box "$box" not found. Register it during init()');
        }
        final metadata = await _getFromBoxBase<Map<String, dynamic>>(customBox, key);
        if (metadata == null) return null;

        // Custom boxes store data as base64
        if (metadata['isCustomBox'] == true) {
          final base64Data = metadata['base64Data'] as String;
          return base64Data.decodeBase64Safely(context: 'custom box file');
        }
        throw StorageReadError('Invalid custom box file metadata for "$key"');
      }

      // If isSecure is specified, use default file boxes
      if (isSecure != null) {
        final metadata = await getFileMetadata(key, isSecure: isSecure);
        if (metadata == null) return null;

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
      }

      // Search all file boxes and detect ambiguity
      final foundBoxes = <String>[];
      Uint8List? result;

      // Check default normal files
      final normalMetadata = await getFileMetadata(key, isSecure: false);
      if (normalMetadata != null) {
        foundBoxes.add('normal_files');
        result = await _fileOperations.getNormalFile(
          fileMetadata: normalMetadata,
          isWeb: kIsWeb,
          getBox: getInternalBox,
        );
      }

      // Check default secure files
      final secureMetadata = await getFileMetadata(key, isSecure: true);
      if (secureMetadata != null) {
        foundBoxes.add('secure_files');
        result = await _fileOperations.getSecureFile(
          fileMetadata: secureMetadata,
          isWeb: kIsWeb,
          secureStorage: _secureStorage,
          getBox: getInternalBox,
        );
      }

      // Check custom boxes
      for (final entry in customBoxes.entries) {
        final metadata = await _getFromBoxBase<Map<String, dynamic>>(entry.value, key);
        if (metadata != null && metadata['isCustomBox'] == true) {
          foundBoxes.add(entry.key);
          final base64Data = metadata['base64Data'] as String;
          result = await base64Data.decodeBase64Safely(context: 'custom box file');
        }
      }

      // If found in multiple boxes, throw ambiguity error
      if (foundBoxes.length > 1) {
        throw AmbiguousKeyError(
          key,
          foundBoxes,
          'File key "$key" found in multiple boxes: ${foundBoxes.join(", ")}. '
          'Specify the box parameter to disambiguate.',
        );
      }

      return result;
    } catch (e) {
      if (e is StorageError) rethrow;
      throw StorageReadError('Failed to get file "$key"', e);
    }
  }

  @override
  Future<void> deleteFile(String key, {String? box}) async {
    _ensureInitialized();

    try {
      // If box specified, delete from custom box only
      if (box != null) {
        final customBox = customBoxes[box];
        if (customBox == null) {
          throw BoxNotFoundError('Box "$box" not found. Register it during init()');
        }
        if (customBox.containsKey(key)) {
          await customBox.delete(key);
        }
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

      // Remove from default file boxes
      final deleteFutures = <Future<void>>[
        if (boxes[BoxType.normalFiles]?.containsKey(key) == true)
          boxes[BoxType.normalFiles]!.delete(key),
        if (boxes[BoxType.secureFiles]?.containsKey(key) == true)
          boxes[BoxType.secureFiles]!.delete(key),
      ];

      // Delete from custom boxes
      for (final entry in customBoxes.entries) {
        if (entry.value.containsKey(key)) {
          deleteFutures.add(entry.value.delete(key));
        }
      }

      await Future.wait<void>(deleteFutures);
    } catch (e) {
      if (e is StorageError) rethrow;
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
    return box == null ? null : await _getFromBoxBase<T>(box, key);
  }

  /// Get value from any BoxBase (handles Box and LazyBox, with legacy support)
  Future<T?> _getFromBoxBase<T>(BoxBase<dynamic> box, String key) async {
    if (!box.containsKey(key)) return null;

    // Get value (sync for Box, async for LazyBox)
    final stored = box is LazyBox<dynamic> ? await box.get(key) : (box as Box<dynamic>).get(key);
    if (stored == null) return null;

    // Legacy support - if it's a plain string, decode as JSON
    if (stored is String) {
      return stored.decodeJsonSafely<T>();
    }

    // New format - check if it's wrapped
    if (stored is Map && StoredValue.isWrapped(stored)) {
      final wrapper = StoredValue.fromHiveMap(stored);

      if (wrapper.strategy == StorageStrategy.native) {
        // Native storage - may need type coercion for primitives
        return _coerceToType<T>(wrapper.value);
      } else {
        // JSON strategy - decode the JSON string
        final jsonString = wrapper.value as String;
        return jsonString.decodeJsonSafely<T>();
      }
    }

    // Fallback for unexpected format or raw primitive values
    // Handle type coercion for primitives that may have been stored directly
    return _coerceToType<T>(stored);
  }

  /// Coerces a value to the expected type T
  ///
  /// Handles backward compatibility for values that may be stored as different types.
  /// Throws StorageReadError on type mismatch to allow graceful error handling.
  T _coerceToType<T>(dynamic value) {
    // If value is already the correct type, return it
    if (value is T) return value;

    // Simple type conversions only - no complex migrations
    if (T == int && value is num) return value.toInt() as T;
    if (T == double && value is num) return value.toDouble() as T;
    if (T == String && value != null) return value.toString() as T;

    // Type mismatch - throw clear error
    throw StorageReadError(
      'Type mismatch: Cannot convert stored value to type $T. '
      'Stored: "$value" (${value.runtimeType}), Expected: $T. '
      'Consider clearing this key if the data is corrupted.',
    );
  }

  /// Set value in a specific box
  @visibleForTesting
  Future<void> setInBox<T>(BoxType boxType, String key, T value) async {
    final box = boxes[boxType];
    if (box == null) {
      throw StorageInitializationError('Box ${boxType.name} not opened. Ensure init() was called.');
    }
    await _putInBoxBase(box, key, value);
  }

  /// Put value into any BoxBase (handles both Box and LazyBox)
  Future<void> _putInBoxBase<T>(BoxBase<dynamic> box, String key, T value) async {
    final strategy = StorageStrategyHelper.determineStrategy(value);

    final toStore = strategy == StorageStrategy.native
        ? StoredValue(value, strategy).toHiveMap() // Wrap for native storage
        : StoredValue(await value.encodeJsonSafely(), strategy)
            .toHiveMap(); // JSON encode then wrap

    // Put into box (both Box and LazyBox have async put)
    await box.put(key, toStore);
  }

  /// Get file metadata with optional storage type specification
  @visibleForTesting
  Future<Map<String, dynamic>?> getFileMetadata(String key, {bool? isSecure}) async {
    // Helper to get metadata from a specific box
    Future<Map<String, dynamic>?> getFromFileBox(BoxType boxType, bool isSecureFile) async {
      final box = boxes[boxType];
      if (box == null || !box.containsKey(key)) return null;

      // Get JSON string (sync for Box, async for LazyBox)
      final jsonString = box is LazyBox<dynamic>
          ? await box.get(key) as String?
          : (box as Box<dynamic>).get(key) as String?;

      if (jsonString == null) return null;

      try {
        final result = await jsonString.decodeJsonSafely<Map<String, dynamic>>();
        return <String, dynamic>{...result, 'isSecure': isSecureFile};
      } catch (e) {
        return null;
      }
    }

    // If isSecure specified, check only that box
    if (isSecure == false) return getFromFileBox(BoxType.normalFiles, false);
    if (isSecure == true) return getFromFileBox(BoxType.secureFiles, true);

    // Otherwise, check both (normal first, then secure)
    return await getFromFileBox(BoxType.normalFiles, false) ??
        await getFromFileBox(BoxType.secureFiles, true);
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

    // Get all keys (both Box and LazyBox expose keys)
    final keyIterable = box.keys;

    for (final key in keyIterable.whereType<String>()) {
      try {
        final metadata = await getFileMetadata(key, isSecure: isSecure);
        if (metadata == null) continue;

        // Delete underlying file
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

  // ==========================================
  // SECURITY METHODS (Android/iOS only)
  // ==========================================

  /// Initialize FreeRASP protection with the provided configuration
  ///
  /// This method is only called on Android and iOS platforms.
  /// On other platforms, security initialization is skipped automatically.
  Future<void> _initializeRaspProtection({
    String? packageName, // Keep internal param name for FreeRASP API
    List<String>? signingCertHashes, // Keep internal param name for FreeRASP API
    String? bundleId, // Keep internal param name for FreeRASP API
    String? teamId, // Keep internal param name for FreeRASP API
  }) async {
    final config = _securityConfig!;

    if (config.enableLogging) {
      debugPrint('VaultStorage: Initializing RASP protection...');
    }

    final talsecConfig = TalsecConfig(
      androidConfig: AndroidConfig(
        packageName: packageName ?? 'your.package.name',
        signingCertHashes: signingCertHashes ?? [],
        supportedStores: ['com.android.vending'], // Google Play Store
      ),
      iosConfig: IOSConfig(
        bundleIds: bundleId != null ? [bundleId] : [],
        teamId: teamId ?? '',
      ),
      watcherMail: config.watcherMail ?? '',
      isProd: config.isProd,
    );

    final threatCallback = ThreatCallback(
      onPrivilegedAccess: () => _handleJailbreakDetection(),
      onAppIntegrity: () => _handleTamperingDetection(),
      onDebug: () => _handleDebugDetection(),
      onHooks: () => _handleHookingDetection(),
      onSimulator: () => _handleEmulatorDetection(),
      onUnofficialStore: () => _handleUnofficialStoreDetection(),
      onScreenshot: () => _handleScreenshotDetection(),
      onScreenRecording: () => _handleScreenRecordingDetection(),
      onSystemVPN: () => _handleSystemVPNDetection(),
      onPasscode: () => _handlePasscodeDetection(),
      onSecureHardwareNotAvailable: () => _handleSecureHardwareDetection(),
      onDevMode: () => _handleDeveloperModeDetection(),
      onADBEnabled: () => _handleADBDetection(),
      onMultiInstance: () => _handleMultiInstanceDetection(),
    );

    Talsec.instance.attachListener(threatCallback);
    await Talsec.instance.start(talsecConfig);

    if (config.enableLogging) {
      debugPrint('VaultStorage: RASP protection initialized successfully');
    }
  }

  /// Check if FreeRASP security features are supported on the current platform
  bool _isSecuritySupportedOnCurrentPlatform() {
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  /// Validate that the environment is secure for vault operations
  void _validateSecureEnvironment() {
    final config = _securityConfig;
    if (config == null) return;

    // Only validate if security features are supported on this platform
    if (!_isSecuritySupportedOnCurrentPlatform()) {
      return;
    }

    if (!isSecureEnvironment) {
      if (config.blockOnJailbreak ||
          config.blockOnTampering ||
          config.blockOnHooks ||
          config.blockOnDebug ||
          config.blockOnEmulator ||
          config.blockOnUnofficialStore) {
        throw const SecurityThreatException(
          'Environment',
          'Vault operations blocked due to detected security threats',
        );
      }
    }
  }

  /// Handle jailbreak/root detection
  void _handleJailbreakDetection() {
    final config = _securityConfig!;

    if (config.enableLogging) {
      debugPrint('VaultStorage: Jailbreak/Root detected');
    }

    isSecureEnvironment = false;

    // Call user-defined callback if provided
    config.threatCallbacks?[SecurityThreat.jailbreak]?.call();

    if (config.blockOnJailbreak) {
      throw const JailbreakDetectedException();
    }
  }

  /// Handle app tampering detection
  void _handleTamperingDetection() {
    final config = _securityConfig!;

    if (config.enableLogging) {
      debugPrint('VaultStorage: App tampering detected');
    }

    isSecureEnvironment = false;

    // Call user-defined callback if provided
    config.threatCallbacks?[SecurityThreat.tampering]?.call();

    if (config.blockOnTampering) {
      throw const TamperingDetectedException();
    }
  }

  /// Handle debug detection
  void _handleDebugDetection() {
    final config = _securityConfig!;

    if (config.enableLogging) {
      debugPrint('VaultStorage: Debugger detected');
    }

    // Call user-defined callback if provided
    config.threatCallbacks?[SecurityThreat.debugging]?.call();

    if (config.blockOnDebug) {
      throw const DebugDetectedException();
    }
  }

  /// Handle hooking framework detection
  void _handleHookingDetection() {
    final config = _securityConfig!;

    if (config.enableLogging) {
      debugPrint('VaultStorage: Hooking framework detected');
    }

    isSecureEnvironment = false;

    // Call user-defined callback if provided
    config.threatCallbacks?[SecurityThreat.hooks]?.call();

    if (config.blockOnHooks) {
      throw const HookingDetectedException();
    }
  }

  /// Handle emulator detection
  void _handleEmulatorDetection() {
    final config = _securityConfig!;

    if (config.enableLogging) {
      debugPrint('VaultStorage: Emulator detected');
    }

    // Call user-defined callback if provided
    config.threatCallbacks?[SecurityThreat.emulator]?.call();

    if (config.blockOnEmulator) {
      throw const EmulatorDetectedException();
    }
  }

  /// Handle unofficial store detection
  void _handleUnofficialStoreDetection() {
    final config = _securityConfig!;

    if (config.enableLogging) {
      debugPrint('VaultStorage: Unofficial store detected');
    }

    isSecureEnvironment = false;

    // Call user-defined callback if provided
    config.threatCallbacks?[SecurityThreat.unofficialStore]?.call();

    if (config.blockOnUnofficialStore) {
      throw const UnofficialStoreDetectedException();
    }
  }

  /// Handle screenshot detection
  void _handleScreenshotDetection() {
    final config = _securityConfig!;

    if (config.enableLogging) {
      debugPrint('VaultStorage: Screenshot detected');
    }

    // Call user-defined callback if provided
    config.threatCallbacks?[SecurityThreat.screenshot]?.call();
  }

  /// Handle screen recording detection
  void _handleScreenRecordingDetection() {
    final config = _securityConfig!;

    if (config.enableLogging) {
      debugPrint('VaultStorage: Screen recording detected');
    }

    // Call user-defined callback if provided
    config.threatCallbacks?[SecurityThreat.screenRecording]?.call();
  }

  /// Handle system VPN detection
  void _handleSystemVPNDetection() {
    final config = _securityConfig!;

    if (config.enableLogging) {
      debugPrint('VaultStorage: System VPN detected');
    }

    // Call user-defined callback if provided
    config.threatCallbacks?[SecurityThreat.systemVPN]?.call();
  }

  /// Handle passcode detection
  void _handlePasscodeDetection() {
    final config = _securityConfig!;

    if (config.enableLogging) {
      debugPrint('VaultStorage: Device passcode not set');
    }

    // Call user-defined callback if provided
    config.threatCallbacks?[SecurityThreat.passcode]?.call();
  }

  /// Handle secure hardware detection
  void _handleSecureHardwareDetection() {
    final config = _securityConfig!;

    if (config.enableLogging) {
      debugPrint('VaultStorage: Secure hardware not available');
    }

    // Call user-defined callback if provided
    config.threatCallbacks?[SecurityThreat.secureHardware]?.call();
  }

  /// Handle developer mode detection
  void _handleDeveloperModeDetection() {
    final config = _securityConfig!;

    if (config.enableLogging) {
      debugPrint('VaultStorage: Developer mode enabled');
    }

    // Call user-defined callback if provided
    config.threatCallbacks?[SecurityThreat.developerMode]?.call();
  }

  /// Handle ADB detection
  void _handleADBDetection() {
    final config = _securityConfig!;

    if (config.enableLogging) {
      debugPrint('VaultStorage: ADB debugging enabled');
    }

    // Call user-defined callback if provided
    config.threatCallbacks?[SecurityThreat.adbEnabled]?.call();
  }

  /// Handle multiple instance detection
  void _handleMultiInstanceDetection() {
    final config = _securityConfig!;

    if (config.enableLogging) {
      debugPrint('VaultStorage: Multiple app instances detected');
    }

    // Call user-defined callback if provided
    config.threatCallbacks?[SecurityThreat.multiInstance]?.call();
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
      boxes[BoxType.secure] = await Hive.openBox<dynamic>(
        StorageKeys.secureBox,
        encryptionCipher: cipher,
        compactionStrategy: vaultCompactionStrategy,
      );
      boxes[BoxType.normal] = await Hive.openBox<dynamic>(
        StorageKeys.normalBox,
        compactionStrategy: vaultCompactionStrategy,
      );

      // Open file storage boxes (lazy boxes for better memory usage)
      boxes[BoxType.secureFiles] = await Hive.openLazyBox<dynamic>(
        StorageKeys.secureFilesBox,
        encryptionCipher: cipher,
        compactionStrategy: vaultCompactionStrategy,
      );
      boxes[BoxType.normalFiles] = await Hive.openLazyBox<dynamic>(
        StorageKeys.normalFilesBox,
        compactionStrategy: vaultCompactionStrategy,
      );
    } catch (e) {
      throw StorageInitializationError('Failed to open storage boxes', e);
    }
  }

  /// Open custom boxes defined by user
  Future<void> _openCustomBoxes(List<BoxConfig> configs, List<int> encryptionKey) async {
    try {
      // Custom compaction strategy
      bool vaultCompactionStrategy(int entries, int deletedEntries) {
        if (entries == 0) return false;
        const deletedRatio = 0.10;
        const deletedThreshold = 30;
        return deletedEntries > deletedThreshold && deletedEntries / entries > deletedRatio;
      }

      for (final config in configs) {
        final cipher = config.encrypted ? HiveAesCipher(encryptionKey) : null;

        if (config.lazy) {
          customBoxes[config.name] = await Hive.openLazyBox<dynamic>(
            config.name,
            encryptionCipher: cipher,
            compactionStrategy: vaultCompactionStrategy,
          );
        } else {
          customBoxes[config.name] = await Hive.openBox<dynamic>(
            config.name,
            encryptionCipher: cipher,
            compactionStrategy: vaultCompactionStrategy,
          );
        }
      }
    } catch (e) {
      throw StorageInitializationError('Failed to open custom boxes', e);
    }
  }
}
