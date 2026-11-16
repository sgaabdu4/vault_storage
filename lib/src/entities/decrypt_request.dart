import 'package:flutter/foundation.dart';

/// Represents a request to decrypt data, typically in a background isolate.
class DecryptRequest {
  /// The encrypted data that needs to be decrypted.
  final Uint8List encryptedBytes;

  /// The raw bytes of the secret key used for decryption.
  final List<int> keyBytes;

  /// The nonce (number used once) associated with the encryption, required for decryption.
  final List<int> nonce;

  /// The Message Authentication Code bytes that verify integrity and authenticity.
  final List<int> macBytes;

  /// Creates a new [DecryptRequest] with the specified components.
  DecryptRequest({
    required this.encryptedBytes,
    required this.keyBytes,
    required this.nonce,
    required this.macBytes,
  });
}
