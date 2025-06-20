import 'package:flutter_test/flutter_test.dart';
import 'package:storage_service/src/constants/storage_keys.dart';

void main() {
  group('StorageKeys', () {
    test('secureKey should have the correct value', () {
      expect(StorageKeys.secureKey, 'hive_encryption_key');
    });

    test('secureBox should have the correct value', () {
      expect(StorageKeys.secureBox, 'secure_box');
    });

    test('normalBox should have the correct value', () {
      expect(StorageKeys.normalBox, 'normal_box');
    });
  });
}
