import 'package:fpdart/fpdart.dart';
import 'package:vault_storage/src/errors/errors.dart';

/// Helper class for executing tasks with proper error handling
class TaskExecutor {
  /// Execute a task with proper error handling
  ///
  /// - [operation] is the actual operation to execute
  /// - [errorBuilder] builds a specific error type from a generic exception
  /// - [isStorageReady] should be set to true if storage is initialized
  Future<Either<StorageError, T>> execute<T>(
    Future<T> Function() operation,
    StorageError Function(Object e) errorBuilder, {
    required bool isStorageReady,
  }) {
    return executeTask(
      TaskEither.tryCatch(
        operation,
        (e, _) => e is StorageSerializationError ? e : errorBuilder(e),
      ),
      isStorageReady: isStorageReady,
    );
  }

  /// Execute a TaskEither with proper error handling
  ///
  /// - [task] is the TaskEither to execute
  /// - [isStorageReady] should be set to true if storage is initialized
  Future<Either<StorageError, T>> executeTask<T>(
    TaskEither<StorageError, T> task, {
    required bool isStorageReady,
  }) {
    if (!isStorageReady) {
      return Future.value(left(const StorageInitializationError('Storage not initialized')));
    }

    return task.mapLeft((l) {
      // If we're already dealing with a StorageSerializationError, return it as is
      if (l is StorageSerializationError) {
        return l;
      }

      // Check if this is a serialization error from our extensions
      // by examining the original exception (which could be a FormatException)
      if (l.originalException is FormatException && !(l is Base64DecodeError)) {
        return StorageSerializationError('${l.message}: ${l.originalException}');
      }

      return l;
    }).run();
  }
}
