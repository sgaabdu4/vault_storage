/// Stub implementation for web download functionality on non-web platforms
library;

import 'dart:typed_data';

/// Stub function for non-web platforms - does nothing since downloads are not needed
void downloadFileOnWeb({
  required Uint8List fileBytes,
  required String fileName,
  String? mimeType,
}) {
  // Do nothing - this function should not be called on non-web platforms
  // The file bytes are returned directly to the caller for them to handle
}
