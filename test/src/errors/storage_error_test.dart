import 'package:flutter_test/flutter_test.dart';
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
        final error =
            StorageSerializationError('Serialization failed', exception);
        expect(error.message, equals('Serialization failed'));
        expect(error.originalException, equals(exception));
      });
    });
  });
}
