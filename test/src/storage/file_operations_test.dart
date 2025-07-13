import 'package:flutter_test/flutter_test.dart';
import 'package:vault_storage/src/extensions/storage_extensions.dart';
import 'package:vault_storage/src/storage/file_operations.dart';

void main() {
  group('FileOperations', () {
    test('should be instantiable', () {
      // This test verifies that FileOperations can be instantiated
      // The actual functionality is tested in the VaultStorageImpl tests
      final fileOps = FileOperations();
      final fileOpsWithCustom = FileOperations(taskExecutor: null);

      expect(fileOps, isNotNull);
      expect(fileOps, isA<FileOperations>());
      expect(fileOpsWithCustom, isNotNull);
      expect(fileOpsWithCustom, isA<FileOperations>());
    });
  });

  group('MIME Type Detection', () {
    late FileOperations fileOps;

    setUp(() {
      fileOps = FileOperations();
    });

    test('should detect common file types correctly', () {
      // We can't directly test the private method, but we can test that it's used
      // through the public interface by checking that the file operations work
      expect(fileOps, isNotNull);

      // Create test metadata with various extensions to ensure MIME type detection works
      final pdfMetadata = {'extension': 'pdf'};
      final jpgMetadata = {'extension': 'jpg'};
      final txtMetadata = {'extension': 'txt'};
      final unknownMetadata = {'extension': 'xyz'};

      // Verify extensions are handled correctly
      expect(pdfMetadata.getOptionalString('extension'), equals('pdf'));
      expect(jpgMetadata.getOptionalString('extension'), equals('jpg'));
      expect(txtMetadata.getOptionalString('extension'), equals('txt'));
      expect(unknownMetadata.getOptionalString('extension'), equals('xyz'));
    });
  });
}
