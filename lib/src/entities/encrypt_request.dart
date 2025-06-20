import 'package:flutter/foundation.dart';

/// Represents a request to encrypt data, designed to be used in background isolates.
///
/// This class bundles the data to be encrypted (`fileBytes`) and the encryption
/// key (`keyBytes`) into a single object. This is particularly useful for passing
/// all necessary information to a separate isolate for performing encryption
/// without blocking the main UI thread.
class EncryptRequest {
  /// The raw data that needs to be encrypted.
  final Uint8List fileBytes;

  /// The secret key to be used for the encryption process.
  final List<int> keyBytes;

  /// Creates a new [EncryptRequest] with the data and key required for encryption.
  EncryptRequest({required this.fileBytes, required this.keyBytes});
}
