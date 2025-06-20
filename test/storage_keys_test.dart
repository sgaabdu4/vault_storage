import 'package:flutter_test/flutter_test.dart';
import 'package:storage_service/src/constants/storage_keys.dart';

void main() {
  group('StorageKeys', () {
    test('secureKey is correct', () {
      expect(StorageKeys.secureKey, 'hive_encryption_key');
    });
    test('secureBox is correct', () {
      expect(StorageKeys.secureBox, 'secure_box');
    });
    test('normalBox is correct', () {
      expect(StorageKeys.normalBox, 'normal_box');
    });
  });
}
