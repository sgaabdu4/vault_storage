import 'dart:typed_data' show Uint8List;

import 'package:vault_storage/src/errors/storage_error.dart';

/// Simple, secure storage for Flutter apps.
///
/// This interface provides a clean API for both key-value storage and file storage,
/// with automatic encryption for secure data. Methods throw [VaultStorageError]
/// exceptions when operations fail.
abstract class IVaultStorage {
  /// Initialize storage. Call this once when your app starts.
  ///
  /// Platform-specific security configuration (Android/iOS) should be provided
  /// in VaultSecurityConfig during create(), not here.
  ///
  /// Example:
  /// ```dart
  /// final storage = VaultStorage.create(
  ///   securityConfig: VaultSecurityConfig.production(
  ///     watcherMail: 'security@app.com',
  ///     androidPackageName: 'com.example.app',
  ///     iosBundleId: 'com.example.app',
  ///   ),
  /// );
  /// await storage.init();
  /// ```
  ///
  /// Throws [VaultStorageError] if initialization fails.
  /// Throws [SecurityThreatException] if security threats are detected during init.
  Future<void> init();

  // ==========================================
  // KEY-VALUE STORAGE
  // ==========================================

  /// Get any value by key with optional storage type specification.
  ///
  /// - If [box] is specified: Only searches the specified custom box
  /// - If [box] is null and [isSecure] is null (default): Searches all boxes (normal, secure, and custom)
  ///   and throws [AmbiguousKeyError] if the key exists in multiple boxes
  /// - If [isSecure] is true: Only searches secure storage
  /// - If [isSecure] is false: Only searches normal storage
  ///
  /// Returns null if the key is not found in the specified storage(s).
  /// Throws [VaultStorageError] if the operation fails.
  /// Throws [BoxNotFoundError] if the specified box was not registered during init.
  /// Throws [AmbiguousKeyError] if the key exists in multiple boxes and no specific box is specified.
  Future<T?> get<T>(String key, {bool? isSecure, String? box});

  /// Store sensitive data with encryption.
  ///
  /// If [box] is specified, stores in the custom box (encryption determined by box config).
  /// If [box] is null, stores in the default secure box.
  ///
  /// Throws [VaultStorageError] if the operation fails.
  /// Throws [BoxNotFoundError] if the specified box was not registered during init.
  Future<void> saveSecure<T>({required String key, required T value, String? box});

  /// Store normal data without encryption (faster).
  ///
  /// If [box] is specified, stores in the custom box (encryption determined by box config).
  /// If [box] is null, stores in the default normal box.
  ///
  /// Throws [VaultStorageError] if the operation fails.
  /// Throws [BoxNotFoundError] if the specified box was not registered during init.
  Future<void> saveNormal<T>({required String key, required T value, String? box});

  /// Delete key from storage.
  ///
  /// If [box] is specified, deletes from the custom box only.
  /// If [box] is null, deletes from all boxes (normal, secure, and all custom boxes).
  ///
  /// Throws [VaultStorageError] if the operation fails.
  /// Throws [BoxNotFoundError] if the specified box was not registered during init.
  Future<void> delete(String key, {String? box});

  /// Clear all normal storage.
  ///
  /// When [includeFiles] is true, also deletes normal file metadata and the
  /// underlying file contents.
  /// Throws [VaultStorageError] if the operation fails.
  Future<void> clearNormal({bool includeFiles = false});

  /// Clear all secure storage.
  ///
  /// When [includeFiles] is true, also deletes secure file metadata and the
  /// underlying encrypted file contents.
  /// Throws [VaultStorageError] if the operation fails.
  Future<void> clearSecure({bool includeFiles = false});

  /// Clear all storage in one call.
  ///
  /// When [includeFiles] is true (default), this performs a complete wipe:
  /// - Normal and secure key-value boxes
  /// - Normal and secure file metadata boxes, and deletes underlying files
  /// - Master encryption key from secure storage (forcing key regeneration on next init)
  ///
  /// When [includeFiles] is false, only key-value data is cleared and the master
  /// encryption key is preserved.
  /// Throws [VaultStorageError] if the operation fails.
  Future<void> clearAll({bool includeFiles = true});

  /// List stored keys.
  ///
  /// - If [isSecure] is null (default): returns keys from both normal and secure storages
  /// - If [isSecure] is true: returns keys from secure storage only
  /// - If [isSecure] is false: returns keys from normal storage only
  ///
  /// When [includeFiles] is true (default), file keys are included as well.
  /// Keys are unique; duplicates across boxes are de-duplicated.
  Future<List<String>> keys({bool includeFiles = true, bool? isSecure});

  // ==========================================
  // FILE STORAGE
  // ==========================================

  /// Store a file with encryption.
  ///
  /// If [box] is specified, stores in the custom box (encryption determined by box config).
  /// If [box] is null, stores in the default secure files box.
  ///
  /// Throws [VaultStorageError] if the operation fails.
  /// Throws [BoxNotFoundError] if the specified box was not registered during init.
  Future<void> saveSecureFile({
    required String key,
    required Uint8List fileBytes,
    String? originalFileName,
    Map<String, dynamic>? metadata,
    String? box,
  });

  /// Store a file without encryption (faster).
  ///
  /// If [box] is specified, stores in the custom box (encryption determined by box config).
  /// If [box] is null, stores in the default normal files box.
  ///
  /// Throws [VaultStorageError] if the operation fails.
  /// Throws [BoxNotFoundError] if the specified box was not registered during init.
  Future<void> saveNormalFile({
    required String key,
    required Uint8List fileBytes,
    String? originalFileName,
    Map<String, dynamic>? metadata,
    String? box,
  });

  /// Get file content with optional storage type specification.
  ///
  /// If [box] is specified: Only searches the specified custom box
  /// If [box] is null and [isSecure] is null (default): Searches all file boxes
  ///   and throws [AmbiguousKeyError] if the key exists in multiple boxes
  /// If [isSecure] is true: Only searches secure files storage
  /// If [isSecure] is false: Only searches normal files storage
  ///
  /// Returns null if the file is not found.
  /// Throws [VaultStorageError] if the operation fails.
  /// Throws [BoxNotFoundError] if the specified box was not registered during init.
  /// Throws [AmbiguousKeyError] if the key exists in multiple boxes and no specific box is specified.
  Future<Uint8List?> getFile(String key, {bool? isSecure, String? box});

  /// Delete file from storage.
  ///
  /// If [box] is specified, deletes from the custom box only.
  /// If [box] is null, deletes from all file boxes (normal files, secure files, and all custom file boxes).
  ///
  /// Throws [VaultStorageError] if the operation fails.
  /// Throws [BoxNotFoundError] if the specified box was not registered during init.
  Future<void> deleteFile(String key, {String? box});

  /// Clean up resources.
  /// Throws [VaultStorageError] if the operation fails.
  Future<void> dispose();
}
