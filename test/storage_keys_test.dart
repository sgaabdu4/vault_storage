import 'package:flutter_test/flutter_test.dart';
import 'package:vault_storage/src/constants/storage_keys.dart';

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

    test('secureFilesBox should have the correct value', () {
      expect(StorageKeys.secureFilesBox, 'secure_files_box');
    });

    test('normalFilesBox should have the correct value', () {
      expect(StorageKeys.normalFilesBox, 'normal_files_box');
    });
  });
}
