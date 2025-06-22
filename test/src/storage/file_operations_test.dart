import 'package:flutter_test/flutter_test.dart';
import 'package:vault_storage/src/errors/errors.dart';
import 'package:vault_storage/src/extensions/storage_extensions.dart';
import 'package:vault_storage/src/storage/file_operations.dart';

void main() {
  group('FileOperations', () {
    test('should be instantiable', () {
      // This test verifies that FileOperations can be instantiated
      // The actual functionality is tested in the VaultStorageImpl tests
      final fileOps = FileOperations();

      expect(fileOps, isNotNull);
      expect(fileOps, isA<FileOperations>());
    });

    test('should be instantiable with custom TaskExecutor', () {
      // This test verifies that FileOperations can be instantiated with custom components
      final fileOps = FileOperations(taskExecutor: null);

      expect(fileOps, isNotNull);
      expect(fileOps, isA<FileOperations>());
    });
  });

  group('FileMetadataExtension', () {
    test('should handle metadata properties correctly', () {
      final metadata = {
        'fileName': 'test.txt',
        'mimeType': 'text/plain',
        'size': 1024,
        'filePath': '/path/to/file',
      };

      expect(metadata.getRequiredString('fileName'), equals('test.txt'));
      expect(metadata.getRequiredString('mimeType'), equals('text/plain'));
      expect(metadata.getOptionalString('filePath'), equals('/path/to/file'));
    });

    test('should handle missing optional properties', () {
      final metadata = {
        'fileName': 'test.txt',
        'mimeType': 'text/plain',
        'size': 1024,
      };

      expect(metadata.getRequiredString('fileName'), equals('test.txt'));
      expect(metadata.getOptionalString('filePath'), isNull);
    });

    test('should throw for missing required properties', () {
      final metadata = {
        'mimeType': 'text/plain',
        'size': 1024,
      };

      expect(
        () => metadata.getRequiredString('fileName'),
        throwsA(isA<InvalidMetadataError>()),
      );
    });
  });
}
