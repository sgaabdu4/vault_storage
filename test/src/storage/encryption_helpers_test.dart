import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vault_storage/src/storage/encryption_helpers.dart';
import 'package:vault_storage/src/entities/decrypt_request.dart';
import 'package:vault_storage/src/entities/encrypt_request.dart';

void main() {
  group('Encryption Helpers', () {
    test('encryptInIsolate should encrypt data correctly', () async {
      final plainData = Uint8List.fromList([1, 2, 3, 4, 5]);
      final keyBytes = Uint8List.fromList(
          List.generate(32, (i) => i)); // 32-byte key for AES-256

      final request = EncryptRequest(fileBytes: plainData, keyBytes: keyBytes);
      final secretBox = await encryptInIsolate(request);

      expect(secretBox.cipherText, isNotEmpty);
      expect(secretBox.nonce, isNotEmpty);
      expect(secretBox.mac.bytes, isNotEmpty);

      // The encrypted data should be different from the plaintext
      expect(secretBox.cipherText, isNot(equals(plainData)));
    });

    test('decryptInIsolate should decrypt data correctly', () async {
      final plainData = Uint8List.fromList([1, 2, 3, 4, 5]);
      final keyBytes = Uint8List.fromList(
          List.generate(32, (i) => i)); // 32-byte key for AES-256

      // First encrypt the data
      final encryptRequest =
          EncryptRequest(fileBytes: plainData, keyBytes: keyBytes);
      final secretBox = await encryptInIsolate(encryptRequest);

      // Then decrypt it
      final decryptRequest = DecryptRequest(
        encryptedBytes: Uint8List.fromList(secretBox.cipherText),
        keyBytes: keyBytes,
        nonce: secretBox.nonce,
        macBytes: secretBox.mac.bytes,
      );

      final decryptedData = await decryptInIsolate(decryptRequest);

      // The decrypted data should match the original
      expect(decryptedData, equals(plainData));
    });

    test('encryptionAlgorithm should be AES-GCM with 256-bit key', () {
      expect(encryptionAlgorithm.toString(), contains('AesGcm'));
    });
  });
}
