import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:vault_storage/src/enum/storage_box_type.dart';

/// Interface for file operations handling both secure and normal files
///
/// This interface defines the contract for saving, retrieving, and deleting files,
/// with platform-specific implementations for web and native platforms.
abstract class IFileOperations {
  /// Save a secure (encrypted) file
  ///
  /// Returns metadata needed to retrieve the file later.
  /// Throws [StorageError] if the operation fails.
  Future<Map<String, dynamic>> saveSecureFile({
    required Uint8List fileBytes,
    required String fileExtension,
    required bool? isWeb,
    required FlutterSecureStorage secureStorage,
    required Uuid uuid,
    required BoxBase<dynamic> Function(BoxType) getBox,
  });

  /// Save a secure (encrypted) file using a stream, encrypting in chunks.
  ///
  /// Useful for large files to reduce peak memory usage. Returns metadata
  /// needed to retrieve the file later. Throws [StorageError] on failure.
  Future<Map<String, dynamic>> saveSecureFileStream({
    required Stream<List<int>> stream,
    required String fileExtension,
    required bool? isWeb,
    required FlutterSecureStorage secureStorage,
    required Uuid uuid,
    required BoxBase<dynamic> Function(BoxType) getBox,
    int? chunkSize,
  });

  /// Get a secure (encrypted) file
  ///
  /// Retrieves and decrypts the file using the provided metadata.
  /// Throws [StorageError] if the operation fails.
  Future<Uint8List> getSecureFile({
    required Map<String, dynamic> fileMetadata,
    required bool? isWeb,
    required FlutterSecureStorage secureStorage,
    required BoxBase<dynamic> Function(BoxType) getBox,
    String? downloadFileName, // Optional filename for web downloads
  });

  /// Delete a secure (encrypted) file
  ///
  /// Removes the file and its encryption key from storage.
  /// Throws [StorageError] if the operation fails.
  Future<void> deleteSecureFile({
    required Map<String, dynamic> fileMetadata,
    required bool? isWeb,
    required FlutterSecureStorage secureStorage,
    required BoxBase<dynamic> Function(BoxType) getBox,
  });

  /// Save a normal (unencrypted) file
  ///
  /// Returns metadata needed to retrieve the file later.
  /// Throws [StorageError] if the operation fails.
  Future<Map<String, dynamic>> saveNormalFile({
    required Uint8List fileBytes,
    required String fileExtension,
    required bool? isWeb,
    required Uuid uuid,
    required BoxBase<dynamic> Function(BoxType) getBox,
  });

  /// Get a normal (unencrypted) file
  ///
  /// Retrieves the file using the provided metadata.
  /// Throws [StorageError] if the operation fails.
  Future<Uint8List> getNormalFile({
    required Map<String, dynamic> fileMetadata,
    required bool? isWeb,
    required BoxBase<dynamic> Function(BoxType) getBox,
    String? downloadFileName, // Optional filename for web downloads
  });

  /// Delete a normal (unencrypted) file
  ///
  /// Removes the file from storage.
  /// Throws [StorageError] if the operation fails.
  Future<void> deleteNormalFile({
    required Map<String, dynamic> fileMetadata,
    required bool? isWeb,
    required BoxBase<dynamic> Function(BoxType) getBox,
  });
}
