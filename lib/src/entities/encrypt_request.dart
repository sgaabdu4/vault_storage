import 'package:flutter/foundation.dart';

/// Data class to pass all necessary info for encryption to an isolate.
class EncryptRequest {
  final Uint8List fileBytes;
  final List<int> keyBytes;

  EncryptRequest({required this.fileBytes, required this.keyBytes});
}
