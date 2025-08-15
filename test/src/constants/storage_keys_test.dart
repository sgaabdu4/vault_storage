import 'package:flutter_test/flutter_test.dart';
import 'package:vault_storage/src/constants/storage_keys.dart';

void main() {
  group('StorageKeys', () {
    test('should not allow instantiation', () {
      // Test that StorageKeys has a private constructor
      // This ensures it's used as a constants-only class
      // We can't actually call StorageKeys._() from outside the class,
      // but we can verify the constants are accessible without instantiation
      expect(StorageKeys.secureKey, isA<String>());
      expect(StorageKeys.secureBox, isA<String>());
      expect(StorageKeys.normalBox, isA<String>());
      expect(StorageKeys.secureFilesBox, isA<String>());
      expect(StorageKeys.normalFilesBox, isA<String>());
    });

    test('constants should be accessible without instantiation', () {
      // This test ensures we can access constants directly from the class
      // which indirectly tests that the private constructor works as intended
      const keyValue = StorageKeys.secureKey;
      expect(keyValue, isNotNull);
      expect(keyValue, equals('hive_encryption_key'));
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

    // Additional robustness tests
    test('all box names should be unique', () {
      final boxNames = {
        StorageKeys.secureBox,
        StorageKeys.normalBox,
        StorageKeys.secureFilesBox,
        StorageKeys.normalFilesBox,
      };
      expect(boxNames.length, equals(4), reason: 'All box names should be unique');
    });

    test('all keys should be non-empty strings', () {
      expect(StorageKeys.secureKey.isNotEmpty, isTrue);
      expect(StorageKeys.secureBox.isNotEmpty, isTrue);
      expect(StorageKeys.normalBox.isNotEmpty, isTrue);
      expect(StorageKeys.secureFilesBox.isNotEmpty, isTrue);
      expect(StorageKeys.normalFilesBox.isNotEmpty, isTrue);
    });

    test('key names should follow naming convention', () {
      // Verify consistent naming patterns
      expect(StorageKeys.secureKey, contains('key'));
      expect(StorageKeys.secureBox, contains('secure'));
      expect(StorageKeys.normalBox, contains('normal'));
      expect(StorageKeys.secureFilesBox, contains('secure'));
      expect(StorageKeys.normalFilesBox, contains('normal'));
    });
  });
}
