import 'dart:typed_data' show Uint8List;
import 'package:vault_storage/src/errors/storage_error.dart';

/// Simple, secure storage for Flutter apps.
///
/// This interface provides a clean API for both key-value storage and file storage,
/// with automatic encryption for secure data. Methods throw [StorageError]
/// exceptions when operations fail.
abstract class IVaultStorage {
  /// Initialize storage. Call this once when your app starts.
  ///
  /// Throws [StorageError] if initialization fails.
  Future<void> init();

  // ==========================================
  // KEY-VALUE STORAGE
  // ==========================================

  /// Get any value by key with optional storage type specification.
  ///
  /// - If [isSecure] is null (default): Searches normal storage first, then secure storage
  /// - If [isSecure] is true: Only searches secure storage
  /// - If [isSecure] is false: Only searches normal storage
  ///
  /// Returns null if the key is not found in the specified storage(s).
  /// Throws [StorageError] if the operation fails.
  Future<T?> get<T>(String key, {bool? isSecure});

  /// Store sensitive data with encryption.
  /// Throws [StorageError] if the operation fails.
  Future<void> saveSecure<T>({required String key, required T value});

  /// Store normal data without encryption (faster).
  /// Throws [StorageError] if the operation fails.
  Future<void> saveNormal<T>({required String key, required T value});

  /// Delete key from both storages.
  /// Throws [StorageError] if the operation fails.
  Future<void> delete(String key);

  /// Clear all normal storage.
  /// Throws [StorageError] if the operation fails.
  Future<void> clearNormal();

  /// Clear all secure storage.
  /// Throws [StorageError] if the operation fails.
  Future<void> clearSecure();

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
  /// Throws [StorageError] if the operation fails.
  Future<void> saveSecureFile({
    required String key,
    required Uint8List fileBytes,
    String? originalFileName,
    Map<String, dynamic>? metadata,
  });

  /// Store a file without encryption (faster).
  /// Throws [StorageError] if the operation fails.
  Future<void> saveNormalFile({
    required String key,
    required Uint8List fileBytes,
    String? originalFileName,
    Map<String, dynamic>? metadata,
  });

  /// Get file content with optional storage type specification.
  /// Returns null if the file is not found.
  /// Throws [StorageError] if the operation fails.
  Future<Uint8List?> getFile(String key, {bool? isSecure});

  /// Delete file from both storages.
  /// Throws [StorageError] if the operation fails.
  Future<void> deleteFile(String key);

  /// Clean up resources.
  /// Throws [StorageError] if the operation fails.
  Future<void> dispose();
}
