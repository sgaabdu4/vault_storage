import 'package:vault_storage/src/entities/file_services.dart';

/// A request to save one encrypted file from a stream, encrypted in chunks.
final class SecureFileStreamRequest {
  /// Creates a new [SecureFileStreamRequest].
  const SecureFileStreamRequest({
    required this.stream,
    required this.fileExtension,
    required this.services,
    this.chunkSize,
  });

  /// The plain bytes to encrypt and store.
  final Stream<List<int>> stream;

  /// The extension of the stored file, without a dot.
  final String fileExtension;

  /// The collaborators used to store the file.
  final FileServices services;

  /// The plain size of each encrypted chunk; `null` uses the default.
  final int? chunkSize;
}
