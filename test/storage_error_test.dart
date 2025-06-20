import 'package:flutter_test/flutter_test.dart';
import 'package:storage_service/src/errors/storage_error.dart';

void main() {
  group('StorageError', () {
    test('StorageInitializationError stores message and exception', () {
      final error = StorageInitializationError('init failed', Exception('e'));
      expect(error.message, 'init failed');
      expect(error.originalException.toString(), contains('Exception'));
    });
    test('StorageReadError stores message and exception', () {
      final error = StorageReadError('read failed', Exception('e'));
      expect(error.message, 'read failed');
      expect(error.originalException.toString(), contains('Exception'));
    });
    test('StorageWriteError stores message and exception', () {
      final error = StorageWriteError('write failed', Exception('e'));
      expect(error.message, 'write failed');
      expect(error.originalException.toString(), contains('Exception'));
    });
    test('StorageDeleteError stores message and exception', () {
      final error = StorageDeleteError('delete failed', Exception('e'));
      expect(error.message, 'delete failed');
      expect(error.originalException.toString(), contains('Exception'));
    });
    test('StorageSerializationError stores message and exception', () {
      final error = StorageSerializationError('serialize failed', Exception('e'));
      expect(error.message, 'serialize failed');
      expect(error.originalException.toString(), contains('Exception'));
    });
  });
}
