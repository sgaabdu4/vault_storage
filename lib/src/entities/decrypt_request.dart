import 'package:flutter/foundation.dart';

/// Data class to pass all necessary info for decryption to an isolate.
class DecryptRequest {
  final Uint8List encryptedBytes;
  final List<int> keyBytes;
  final List<int> nonce;
  final List<int> macBytes;

  DecryptRequest({
    required this.encryptedBytes,
    required this.keyBytes,
    required this.nonce,
    required this.macBytes,
  });
}
