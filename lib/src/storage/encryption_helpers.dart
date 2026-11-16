import 'package:cryptography_plus/cryptography_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:vault_storage/src/entities/decrypt_request.dart';
import 'package:vault_storage/src/entities/encrypt_request.dart';

/// The encryption algorithm used by the vault storage
final encryptionAlgorithm = AesGcm.with256bits();

/// Encrypt data in an isolate for better performance
Future<SecretBox> encryptInIsolate(EncryptRequest request) async {
  final secretKey = SecretKey(request.keyBytes);
  return encryptionAlgorithm.encrypt(request.fileBytes, secretKey: secretKey);
}

/// Decrypt data in an isolate for better performance
Future<Uint8List> decryptInIsolate(DecryptRequest request) async {
  final secretKey = SecretKey(request.keyBytes);
  final secretBox = SecretBox(
    request.encryptedBytes,
    nonce: request.nonce,
    mac: Mac(request.macBytes),
  );
  final decryptedData = await encryptionAlgorithm.decrypt(secretBox, secretKey: secretKey);
  return Uint8List.fromList(decryptedData);
}
