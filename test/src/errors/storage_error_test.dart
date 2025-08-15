import 'package:flutter_test/flutter_test.dart';
import 'package:vault_storage/src/errors/file_errors.dart';
import 'package:vault_storage/src/errors/storage_error.dart';

void main() {
  group('StorageError', () {
    group('StorageInitializationError', () {
      test('should create with message only', () {
        const error = StorageInitializationError('Init failed');
        expect(error.message, equals('Init failed'));
        expect(error.originalException, isNull);
      });

      test('should create with message and exception', () {
        final exception = Exception('Original error');
        final error = StorageInitializationError('Init failed', exception);
        expect(error.message, equals('Init failed'));
        expect(error.originalException, equals(exception));
      });
    });

    group('StorageReadError', () {
      test('should create with message only', () {
        const error = StorageReadError('Read failed');
        expect(error.message, equals('Read failed'));
        expect(error.originalException, isNull);
      });

      test('should create with message and exception', () {
        final exception = Exception('Original error');
        final error = StorageReadError('Read failed', exception);
        expect(error.message, equals('Read failed'));
        expect(error.originalException, equals(exception));
      });
    });

    group('StorageWriteError', () {
      test('should create with message only', () {
        const error = StorageWriteError('Write failed');
        expect(error.message, equals('Write failed'));
        expect(error.originalException, isNull);
      });

      test('should create with message and exception', () {
        final exception = Exception('Original error');
        final error = StorageWriteError('Write failed', exception);
        expect(error.message, equals('Write failed'));
        expect(error.originalException, equals(exception));
      });
    });

    group('StorageDeleteError', () {
      test('should create with message only', () {
        const error = StorageDeleteError('Delete failed');
        expect(error.message, equals('Delete failed'));
        expect(error.originalException, isNull);
      });

      test('should create with message and exception', () {
        final exception = Exception('Original error');
        final error = StorageDeleteError('Delete failed', exception);
        expect(error.message, equals('Delete failed'));
        expect(error.originalException, equals(exception));
      });
    });

    group('StorageDisposalError', () {
      test('should create with message only', () {
        const error = StorageDisposalError('Disposal failed');
        expect(error.message, equals('Disposal failed'));
        expect(error.originalException, isNull);
      });

      test('should create with message and exception', () {
        final exception = Exception('Original error');
        final error = StorageDisposalError('Disposal failed', exception);
        expect(error.message, equals('Disposal failed'));
        expect(error.originalException, equals(exception));
      });
    });

    group('StorageSerializationError', () {
      test('should create with message only', () {
        const error = StorageSerializationError('Serialization failed');
        expect(error.message, equals('Serialization failed'));
        expect(error.originalException, isNull);
      });

      test('should create with message and exception', () {
        final exception = Exception('Original error');
        final error = StorageSerializationError('Serialization failed', exception);
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
