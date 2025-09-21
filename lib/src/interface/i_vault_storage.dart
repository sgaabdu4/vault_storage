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
  /// For apps with security features enabled, provide platform-specific configuration:
  ///
  /// **Note**: Security features are only available on Android and iOS platforms.
  /// On other platforms (macOS, Windows, Linux, Web), security configuration
  /// will be ignored and vault storage will work normally.
  ///
  /// [packageName] - Android package name (required for Android security features)
  /// [signingCertHashes] - Android signing certificate hashes in Base64 format
  /// [bundleId] - iOS bundle identifier (required for iOS security features)
  /// [teamId] - iOS team identifier (required for iOS security features)
  ///
  /// Throws [StorageError] if initialization fails.
  /// Throws [SecurityThreatException] if security threats are detected during init.
  Future<void> init({
    String? packageName,
    List<String>? signingCertHashes,
    String? bundleId,
    String? teamId,
  });

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
  ///
  /// When [includeFiles] is true, also deletes normal file metadata and the
  /// underlying file contents.
  /// Throws [StorageError] if the operation fails.
  Future<void> clearNormal({bool includeFiles = false});

  /// Clear all secure storage.
  ///
  /// When [includeFiles] is true, also deletes secure file metadata and the
  /// underlying encrypted file contents.
  /// Throws [StorageError] if the operation fails.
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
  /// Throws [StorageError] if the operation fails.
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
