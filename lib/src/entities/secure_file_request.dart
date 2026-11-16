import 'package:flutter/foundation.dart';
import 'package:vault_storage/src/entities/file_services.dart';

/// A request to save one encrypted file from bytes held in memory.
final class SecureFileRequest {
  /// Creates a new [SecureFileRequest].
  const SecureFileRequest({
    required this.fileBytes,
    required this.fileExtension,
    required this.services,
  });

  /// The plain bytes to encrypt and store.
  final Uint8List fileBytes;

  /// The extension of the stored file, without a dot.
  final String fileExtension;

  /// The collaborators used to store the file.
  final FileServices services;
}
