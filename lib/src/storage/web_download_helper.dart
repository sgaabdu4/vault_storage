/// Web-specific download functionality using package:web
library;

import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

/// Downloads a file in the browser by creating a blob and triggering download
void downloadFileOnWeb({
  required Uint8List fileBytes,
  required String fileName,
  String? mimeType,
}) {
  // Create a blob from the file bytes
  final blob = web.Blob(
      [fileBytes.toJS].toJS,
      web.BlobPropertyBag(
        type: mimeType ?? 'application/octet-stream',
      ));

  // Create a URL for the blob
  final url = web.URL.createObjectURL(blob);

  // Create a temporary anchor element to trigger download
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName
    ..style.display = 'none';

  // Add to DOM, click, and remove
  web.document.body!.appendChild(anchor);
  anchor.click();
  web.document.body!.removeChild(anchor);

  // Clean up the blob URL
  web.URL.revokeObjectURL(url);
}
