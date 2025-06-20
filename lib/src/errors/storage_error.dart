sealed class StorageError {
  const StorageError(this.message, [this.originalException]);
  final String message;
  final Object? originalException;
}

class StorageInitializationError extends StorageError {
  const StorageInitializationError(super.message, [super.originalException]);
}

class StorageReadError extends StorageError {
  const StorageReadError(super.message, [super.originalException]);
}

class StorageWriteError extends StorageError {
  const StorageWriteError(super.message, [super.originalException]);
}

class StorageDeleteError extends StorageError {
  const StorageDeleteError(super.message, [super.originalException]);
}

class StorageSerializationError extends StorageError {
  const StorageSerializationError(super.message, [super.originalException]);
}
