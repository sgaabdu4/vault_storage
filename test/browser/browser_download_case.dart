import 'dart:js_interop';
import 'dart:typed_data';

import 'package:vault_storage/src/storage/web_download_helper.dart';
import 'package:web/web.dart' as web;

Future<void> main() async {
  try {
    await verifyDownload(null, 'application/octet-stream');
    await verifyDownload('text/plain', 'text/plain');
    web.document.body!.setAttribute('data-result', 'passed');
  } catch (error) {
    web.document.body!.setAttribute('data-result', 'failed: $error');
  }
}

Future<void> verifyDownload(String? mimeType, String expectedType) async {
  const name = 'synthetic-download.txt';
  final bytes = Uint8List.fromList([72, 101, 108, 108, 111]);
  final before = web.document.querySelectorAll('a').length;
  Future<web.Response>? response;
  String? blobUrl;
  final listener = ((web.Event event) {
    final target = event.target;
    if (target == null || !target.isA<web.HTMLAnchorElement>()) return;
    final anchor = target as web.HTMLAnchorElement;
    event.preventDefault();
    if (anchor.download != name || anchor.style.display != 'none') {
      throw StateError('Download metadata changed');
    }
    blobUrl = anchor.href;
    response = web.window.fetch(anchor.href.toJS).toDart;
  }).toJS;
  web.document.addEventListener('click', listener);
  try {
    downloadFileOnWeb(fileBytes: bytes, fileName: name, mimeType: mimeType);
  } finally {
    web.document.removeEventListener('click', listener);
  }
  if (response == null || web.document.querySelectorAll('a').length != before) {
    throw StateError('Download was not dispatched or the anchor leaked');
  }
  final result = await response!;
  final actual = (await result.arrayBuffer().toDart).toDart.asUint8List();
  if (result.headers.get('content-type') != expectedType ||
      actual.length != bytes.length ||
      List.generate(bytes.length, (index) => actual[index] == bytes[index]).contains(false)) {
    throw StateError('Downloaded bytes or MIME type changed');
  }
  var revoked = false;
  try {
    await web.window.fetch(blobUrl!.toJS).toDart;
  } catch (_) {
    revoked = true;
  }
  if (!revoked) throw StateError('Object URL was not revoked');
}
