import 'package:flutter/foundation.dart';

/// Represents a request to decrypt data, typically in a background isolate.
///
/// This class encapsulates all the necessary components for decryption, including the
/// encrypted data, the encryption key, the nonce (number used once), and the MAC
/// (Message Authentication Code) bytes. This structure is essential for securely
/// passing data to and from isolates for cryptographic operations.
class DecryptRequest {
  /// The encrypted data that needs to be decrypted.
  final Uint8List encryptedBytes;

  /// The raw bytes of the secret key used for decryption.
  final List<int> keyBytes;

  /// The nonce (number used once) associated with the encryption, required for decryption.
  final List<int> nonce;

  /// The Message Authentication Code bytes, used to verify the integrity and
  /// authenticity of the encrypted data.
  final List<int> macBytes;

  /// Creates a new [DecryptRequest] with the specified components.
  DecryptRequest({
    required this.encryptedBytes,
    required this.keyBytes,
    required this.nonce,
    required this.macBytes,
  });
}
