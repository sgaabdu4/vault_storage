/// Web-specific download functionality using package:web
library;

import 'dart:js_interop';
import 'dart:typed_data';
import 'package:vault_storage/src/errors/storage_error.dart';
import 'package:web/web.dart' as web;

const _defaultMimeType = 'application/octet-stream';

/// Downloads a file in the browser by creating a blob and triggering download
void downloadFileOnWeb({required Uint8List fileBytes, required String fileName, String? mimeType}) {
  final body = web.document.body;
  if (body == null) {
    throw const VaultStorageWriteError('The browser document has no body to hold the download.');
  }

  // Create a blob from the file bytes
  final blob = web.Blob(
    [fileBytes.toJS].toJS,
    web.BlobPropertyBag(type: mimeType ?? _defaultMimeType),
  );

  // Create a URL for the blob
  final url = web.URL.createObjectURL(blob);

  // Create a temporary anchor element to trigger download
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName
    ..style.display = 'none';

  // Add to DOM, click, and remove
  body.appendChild(anchor);
  anchor.click();
  body.removeChild(anchor);

  // Clean up the blob URL
  web.URL.revokeObjectURL(url);
}
