import 'package:flutter_test/flutter_test.dart';
import 'package:vault_storage/src/errors/file_errors.dart';
import 'package:vault_storage/src/errors/storage_error.dart';

void main() {
  group('VaultStorageError', () {
    group('VaultStorageInitializationError', () {
      test('should create with message only', () {
        const error = VaultStorageInitializationError('Init failed');
        expect(error.message, equals('Init failed'));
        expect(error.originalException, isNull);
      });

      test('should create with message and exception', () {
        final exception = Exception('Original error');
        final error = VaultStorageInitializationError('Init failed', exception);
        expect(error.message, equals('Init failed'));
        expect(error.originalException, equals(exception));
      });
    });

    group('VaultStorageReadError', () {
      test('should create with message only', () {
        const error = VaultStorageReadError('Read failed');
        expect(error.message, equals('Read failed'));
        expect(error.originalException, isNull);
      });

      test('should create with message and exception', () {
        final exception = Exception('Original error');
        final error = VaultStorageReadError('Read failed', exception);
        expect(error.message, equals('Read failed'));
        expect(error.originalException, equals(exception));
      });
    });

    group('VaultStorageWriteError', () {
      test('should create with message only', () {
        const error = VaultStorageWriteError('Write failed');
        expect(error.message, equals('Write failed'));
        expect(error.originalException, isNull);
      });

      test('should create with message and exception', () {
        final exception = Exception('Original error');
        final error = VaultStorageWriteError('Write failed', exception);
        expect(error.message, equals('Write failed'));
        expect(error.originalException, equals(exception));
      });
    });

    group('VaultStorageDeleteError', () {
      test('should create with message only', () {
        const error = VaultStorageDeleteError('Delete failed');
        expect(error.message, equals('Delete failed'));
        expect(error.originalException, isNull);
      });

      test('should create with message and exception', () {
        final exception = Exception('Original error');
        final error = VaultStorageDeleteError('Delete failed', exception);
        expect(error.message, equals('Delete failed'));
        expect(error.originalException, equals(exception));
      });
    });

    group('VaultStorageDisposalError', () {
      test('should create with message only', () {
        const error = VaultStorageDisposalError('Disposal failed');
        expect(error.message, equals('Disposal failed'));
        expect(error.originalException, isNull);
      });

      test('should create with message and exception', () {
        final exception = Exception('Original error');
        final error = VaultStorageDisposalError('Disposal failed', exception);
        expect(error.message, equals('Disposal failed'));
        expect(error.originalException, equals(exception));
      });
    });

    group('VaultStorageSerializationError', () {
      test('should create with message only', () {
        const error = VaultStorageSerializationError('Serialization failed');
        expect(error.message, equals('Serialization failed'));
        expect(error.originalException, isNull);
      });

      test('should create with message and exception', () {
        final exception = Exception('Original error');
        final error = VaultStorageSerializationError('Serialization failed', exception);
        expect(error.message, equals('Serialization failed'));
        expect(error.originalException, equals(exception));
      });
    });
  });

  group('FileError', () {
    group('Base64DecodeError', () {
      test('should create with context and exception', () {
        final exception = Exception('Original error');
        final error = Base64DecodeError('encryption key', exception);
        expect(error.message, equals('Failed to decode base64 for encryption key'));
        expect(error.originalException, equals(exception));
      });

      test('should create with context and null exception', () {
        final error = Base64DecodeError('file content', null);
        expect(error.message, equals('Failed to decode base64 for file content'));
        expect(error.originalException, isNull);
      });
    });

    group('FileNotFoundError', () {
      test('should create with fileId and location', () {
        final error = FileNotFoundError('file123', 'storage box');
        expect(error.message, equals('File not found: ID file123 in storage box'));
        expect(error.originalException, isNull);
      });
    });

    group('InvalidMetadataError', () {
      test('should create with missing field name', () {
        final error = InvalidMetadataError('filePath');
        expect(error.message, equals('Invalid file metadata: missing filePath'));
        expect(error.originalException, isNull);
      });
    });

    group('KeyNotFoundError', () {
      test('should create with key name', () {
        final error = KeyNotFoundError('encryptionKey');
        expect(error.message, equals('Encryption key not found in secure storage: encryptionKey'));
        expect(error.originalException, isNull);
      });
    });
  });
}
