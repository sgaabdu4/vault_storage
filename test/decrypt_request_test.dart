import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:storage_service/src/entities/decrypt_request.dart';

void main() {
  group('DecryptRequest', () {
    test('constructor assigns fields correctly', () {
      final encryptedBytes = Uint8List.fromList([1, 2, 3]);
      final keyBytes = [4, 5, 6];
      final nonce = [7, 8, 9];
      final macBytes = [10, 11, 12];
      final req = DecryptRequest(
        encryptedBytes: encryptedBytes,
        keyBytes: keyBytes,
        nonce: nonce,
        macBytes: macBytes,
      );
      expect(req.encryptedBytes, encryptedBytes);
      expect(req.keyBytes, keyBytes);
      expect(req.nonce, nonce);
      expect(req.macBytes, macBytes);
    });
  });
}
