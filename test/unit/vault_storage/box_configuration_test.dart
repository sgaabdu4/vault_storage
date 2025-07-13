// test/unit/vault_storage/box_configuration_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:vault_storage/src/constants/storage_keys.dart';
import 'package:vault_storage/src/enum/storage_box_type.dart';
import 'package:vault_storage/src/enum/internal_storage_box_type.dart';

void main() {
  group('Box Configuration', () {
    test('box types should map to the correct storage keys', () {
      expect(BoxType.secure.name, equals('secure'));
      expect(BoxType.normal.name, equals('normal'));
      
      // Test internal box types that are used for file storage
      expect(InternalBoxType.secureFiles.name, equals('secureFiles'));
      expect(InternalBoxType.normalFiles.name, equals('normalFiles'));

      expect(StorageKeys.secureBox, equals('secure_box'));
      expect(StorageKeys.normalBox, equals('normal_box'));
      expect(StorageKeys.secureFilesBox, equals('secure_files_box'));
      expect(StorageKeys.normalFilesBox, equals('normal_files_box'));
    });
  });
}
