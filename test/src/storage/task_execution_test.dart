import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:vault_storage/src/errors/errors.dart';
import 'package:vault_storage/src/storage/task_execution.dart';

void main() {
  group('TaskExecutor', () {
    late TaskExecutor taskExecutor;

    setUp(() {
      taskExecutor = TaskExecutor();
    });

    group('execute', () {
      test('should return right for successful operation', () async {
        final result = await taskExecutor.execute<String>(
          () async => 'success',
          (e) => StorageReadError('Test failed', e),
          isStorageReady: true,
        );

        expect(result.isRight(), isTrue);
        expect(result.getRight().toNullable(), equals('success'));
      });

      test(
          'should return left with StorageInitializationError when storage is not ready',
          () async {
        final result = await taskExecutor.execute<String>(
          () async => 'success',
          (e) => StorageReadError('Test failed', e),
          isStorageReady: false,
        );

        expect(result.isLeft(), isTrue);
        expect(
            result.getLeft().toNullable(), isA<StorageInitializationError>());
      });

      test('should return left with custom error when operation fails',
          () async {
        final exception = Exception('Test exception');
        final result = await taskExecutor.execute<String>(
          () async => throw exception,
          (e) => StorageReadError('Test failed', e),
          isStorageReady: true,
        );

        expect(result.isLeft(), isTrue);
        final error = result.getLeft().toNullable() as StorageReadError;
        expect(error.message, equals('Test failed'));
        expect(error.originalException, equals(exception));
      });

      test('should return StorageSerializationError directly if thrown',
          () async {
        const serializationError =
            StorageSerializationError('Serialization error');
        final result = await taskExecutor.execute<String>(
          () async => throw serializationError,
          (e) => StorageReadError('Test failed', e),
          isStorageReady: true,
        );

        expect(result.isLeft(), isTrue);
        expect(result.getLeft().toNullable(), equals(serializationError));
      });
    });

    group('executeTask', () {
      test('should return right for successful task', () async {
        final task = TaskEither<StorageError, String>.of('success');
        final result = await taskExecutor.executeTask<String>(
          task,
          isStorageReady: true,
        );

        expect(result.isRight(), isTrue);
        expect(result.getRight().toNullable(), equals('success'));
      });

      test(
          'should return left with StorageInitializationError when storage is not ready',
          () async {
        final task = TaskEither<StorageError, String>.of('success');
        final result = await taskExecutor.executeTask<String>(
          task,
          isStorageReady: false,
        );

        expect(result.isLeft(), isTrue);
        expect(
            result.getLeft().toNullable(), isA<StorageInitializationError>());
      });

      test('should keep StorageSerializationError as is', () async {
        const serializationError =
            StorageSerializationError('Serialization error');
        final task = TaskEither<StorageError, String>.left(serializationError);
        final result = await taskExecutor.executeTask<String>(
          task,
          isStorageReady: true,
        );

        expect(result.isLeft(), isTrue);
        expect(result.getLeft().toNullable(), equals(serializationError));
      });

      test('should convert FormatException to StorageSerializationError',
          () async {
        const formatError =
            StorageReadError('Format error', FormatException('Invalid format'));
        final task = TaskEither<StorageError, String>.left(formatError);
        final result = await taskExecutor.executeTask<String>(
          task,
          isStorageReady: true,
        );

        expect(result.isLeft(), isTrue);
        expect(result.getLeft().toNullable(), isA<StorageSerializationError>());
      });

      test('should not convert Base64DecodeError to StorageSerializationError',
          () async {
        final base64Error = Base64DecodeError(
            'test context', const FormatException('Invalid base64'));
        final task = TaskEither<StorageError, String>.left(base64Error);
        final result = await taskExecutor.executeTask<String>(
          task,
          isStorageReady: true,
        );

        expect(result.isLeft(), isTrue);
        expect(result.getLeft().toNullable(), equals(base64Error));
      });

      test('should keep other errors as is', () async {
        const otherError = StorageReadError('Other error');
        final task = TaskEither<StorageError, String>.left(otherError);
        final result = await taskExecutor.executeTask<String>(
          task,
          isStorageReady: true,
        );

        expect(result.isLeft(), isTrue);
        expect(result.getLeft().toNullable(), equals(otherError));
      });
    });
  });
}
