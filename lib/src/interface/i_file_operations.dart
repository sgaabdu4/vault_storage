import 'dart:typed_data';

import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:vault_storage/src/entities/normal_file_request.dart';
import 'package:vault_storage/src/entities/secure_file_request.dart';
import 'package:vault_storage/src/entities/secure_file_stream_request.dart';
import 'package:vault_storage/src/enum/box_type.dart';
import 'package:vault_storage/src/interface/i_secure_key_store.dart';

/// Interface for file operations handling both secure and normal files
abstract interface class IFileOperations {
  /// Save a secure (encrypted) file
  Future<Map<String, dynamic>> saveSecureFile(SecureFileRequest request);

  /// Save a secure (encrypted) file using a stream, encrypting in chunks.
  Future<Map<String, dynamic>> saveSecureFileStream(SecureFileStreamRequest request);

  /// Get a secure (encrypted) file
  Future<Uint8List> getSecureFile({
    required Map<String, dynamic> fileMetadata,
    required bool? isWeb,
    required ISecureKeyStore secureStorage,
    required BoxBase<Object?> Function(BoxType) getBox,
    String? downloadFileName, // Optional filename for web downloads
  });

  /// Delete a secure (encrypted) file
  Future<void> deleteSecureFile({
    required Map<String, dynamic> fileMetadata,
    required bool? isWeb,
    required ISecureKeyStore secureStorage,
    required BoxBase<Object?> Function(BoxType) getBox,
  });

  /// Save a normal (unencrypted) file
  Future<Map<String, dynamic>> saveNormalFile(NormalFileRequest request);

  /// Get a normal (unencrypted) file
  Future<Uint8List> getNormalFile({
    required Map<String, dynamic> fileMetadata,
    required bool? isWeb,
    required BoxBase<Object?> Function(BoxType) getBox,
    String? downloadFileName, // Optional filename for web downloads
  });

  /// Delete a normal (unencrypted) file
  Future<void> deleteNormalFile({
    required Map<String, dynamic> fileMetadata,
    required bool? isWeb,
    required BoxBase<Object?> Function(BoxType) getBox,
  });
}
