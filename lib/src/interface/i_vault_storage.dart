import 'dart:typed_data' show Uint8List;

/// Simple, secure storage for Flutter apps.
abstract class IVaultStorage {
  /// Initialize storage. Call this once when your app starts.
  Future<void> init();

  // ==========================================

  /// Get any value by key with optional storage type specification.
  Future<T?> get<T>(String key, {bool? isSecure, String? box});

  /// Store sensitive data with encryption.
  Future<void> saveSecure<T>({required String key, required T value, String? box});

  /// Store normal data without encryption (faster).
  Future<void> saveNormal<T>({required String key, required T value, String? box});

  /// Delete key from storage.
  Future<void> delete(String key, {String? box});

  /// Clear all normal storage.
  Future<void> clearNormal({bool includeFiles = false});

  /// Clear all secure storage.
  Future<void> clearSecure({bool includeFiles = false});

  /// Clear all storage in one call.
  Future<void> clearAll({bool includeFiles = true});

  /// List stored keys.
  Future<List<String>> keys({bool includeFiles = true, bool? isSecure});

  // ==========================================

  /// Store a file with encryption.
  Future<void> saveSecureFile({
    required String key,
    required Uint8List fileBytes,
    String? originalFileName,
    Map<String, dynamic>? metadata,
    String? box,
  });

  /// Store a file without encryption (faster).
  Future<void> saveNormalFile({
    required String key,
    required Uint8List fileBytes,
    String? originalFileName,
    Map<String, dynamic>? metadata,
    String? box,
  });

  /// Get file content with optional storage type specification.
  Future<Uint8List?> getFile(String key, {bool? isSecure, String? box});

  /// Delete file from storage.
  Future<void> deleteFile(String key, {String? box});

  /// Clean up resources.
  Future<void> dispose();
}
