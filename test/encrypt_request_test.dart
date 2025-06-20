import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:storage_service/src/entities/encrypt_request.dart';

void main() {
  group('EncryptRequest', () {
    test('constructor assigns fields correctly', () {
      final fileBytes = Uint8List.fromList([1, 2, 3]);
      final keyBytes = [4, 5, 6];
      final req = EncryptRequest(fileBytes: fileBytes, keyBytes: keyBytes);
      expect(req.fileBytes, fileBytes);
      expect(req.keyBytes, keyBytes);
    });
  });
}
