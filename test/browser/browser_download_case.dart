import 'dart:js_interop';
import 'dart:typed_data';

import 'package:vault_storage/src/storage/web_download_helper.dart';
import 'package:web/web.dart' as web;

import 'browser_check_failure.dart';

Future<void> main() async {
  try {
    await verifyDownload(null, 'application/octet-stream');
    await verifyDownload('text/plain', 'text/plain');
    _report('passed');
  } catch (error) {
    _report('failed: $error');
  }
}

void _report(String result) => web.document.body?.setAttribute('data-result', result);

Future<void> verifyDownload(String? mimeType, String expectedType) async {
  const name = 'synthetic-download.txt';
  final bytes = Uint8List.fromList([72, 101, 108, 108, 111]);
  final before = web.document.querySelectorAll('a').length;
  Future<web.Response>? response;
  String blobUrl = '';
  final listener = ((web.Event event) {
    final anchor = web.document.querySelector('a[download]');
    if (anchor == null) return;
    event.preventDefault();
    final display = anchor.getAttribute('style') ?? '';
    if (anchor.getAttribute('download') != name || !display.contains('display: none')) {
      throw const BrowserCheckFailure('Download metadata changed');
    }
    blobUrl = anchor.getAttribute('href') ?? '';
    response = web.window.fetch(blobUrl.toJS).toDart;
  }).toJS;
  web.document.addEventListener('click', listener);
  try {
    downloadFileOnWeb(fileBytes: bytes, fileName: name, mimeType: mimeType);
  } finally {
    web.document.removeEventListener('click', listener);
  }
  final result = switch (response) {
    final Future<web.Response> pending when web.document.querySelectorAll('a').length == before =>
      await pending,
    _ => throw const BrowserCheckFailure('Download was not dispatched or the anchor leaked'),
  };
  final actual = (await result.arrayBuffer().toDart).toDart.asUint8List();
  if (result.headers.get('content-type') != expectedType ||
      actual.length != bytes.length ||
      List.generate(bytes.length, (index) => actual[index] == bytes[index]).contains(false)) {
    throw const BrowserCheckFailure('Downloaded bytes or MIME type changed');
  }
  bool revoked = false;
  try {
    await web.window.fetch(blobUrl.toJS).toDart;
  } catch (_) {
    revoked = true;
  }
  if (!revoked) throw const BrowserCheckFailure('Object URL was not revoked');
}
