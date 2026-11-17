import 'package:flutter/foundation.dart';
import 'package:vault_storage/src/entities/file_services.dart';

/// A request to save one unencrypted file.
final class NormalFileRequest {
  /// Creates a new [NormalFileRequest].
  const NormalFileRequest({
    required this.fileBytes,
    required this.fileExtension,
    required this.services,
  });

  /// The bytes to store.
  final Uint8List fileBytes;

  /// The extension of the stored file, without a dot.
  final String fileExtension;

  /// The collaborators used to store the file.
  final FileServices services;
}
