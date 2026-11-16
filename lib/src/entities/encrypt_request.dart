import 'package:flutter/foundation.dart';

/// Represents a request to encrypt data, designed to be used in background isolates.
class EncryptRequest {
  /// The raw data that needs to be encrypted.
  final Uint8List fileBytes;

  /// The secret key to be used for the encryption process.
  final List<int> keyBytes;

  /// Creates a new [EncryptRequest] with the data and key required for encryption.
  EncryptRequest({required this.fileBytes, required this.keyBytes});
}
