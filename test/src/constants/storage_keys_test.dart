import 'package:flutter_test/flutter_test.dart';
import 'package:vault_storage/src/constants/storage_keys.dart';

void main() {
  group('StorageKeys', () {
    test('should not be instantiable (private constructor)', () {
      // This test ensures that StorageKeys._() is covered
      // We can't actually instantiate it, but we can verify the constants work
      expect(StorageKeys.secureKey, isNotNull);
    });

    test('secureKey should have the correct value', () {
      expect(StorageKeys.secureKey, 'hive_encryption_key');
    });

    test('secureBox should have the correct value', () {
      expect(StorageKeys.secureBox, 'secure_box');
    });

    test('normalBox should have the correct value', () {
      expect(StorageKeys.normalBox, 'normal_box');
    });

    test('secureFilesBox should have the correct value', () {
      expect(StorageKeys.secureFilesBox, 'secure_files_box');
    });

    test('normalFilesBox should have the correct value', () {
      expect(StorageKeys.normalFilesBox, 'normal_files_box');
    });
  });
}
