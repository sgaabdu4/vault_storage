/// A sealed class representing the various errors that can occur within the vault storage.
sealed class VaultStorageError implements Exception {
  /// Creates a new [VaultStorageError] with a [message] and an optional [originalException].
  const VaultStorageError(this.message, [this.originalException]);

  /// A descriptive message explaining the nature of the error.
  final String message;

  /// The original exception or error object that was caught, if any.
  final Object? originalException;

  @override
  String toString() {
    final buffer = StringBuffer('$runtimeType: $message');
    if (originalException case final Object cause) {
      buffer.write(' (caused by: $cause)');
    }
    return buffer.toString();
  }
}

/// An error that occurs during the initialization of the vault storage.
class VaultStorageInitializationError extends VaultStorageError {
  /// Creates a new [VaultStorageInitializationError].
  const VaultStorageInitializationError(super.message, [super.originalException]);
}

/// An error that occurs when attempting to read data from storage.
class VaultStorageReadError extends VaultStorageError {
  /// Creates a new [VaultStorageReadError].
  const VaultStorageReadError(super.message, [super.originalException]);
}

/// An error that occurs when attempting to write data to storage.
class VaultStorageWriteError extends VaultStorageError {
  /// Creates a new [VaultStorageWriteError].
  const VaultStorageWriteError(super.message, [super.originalException]);
}

/// An error that occurs when attempting to delete data from storage.
class VaultStorageDeleteError extends VaultStorageError {
  /// Creates a new [VaultStorageDeleteError].
  const VaultStorageDeleteError(super.message, [super.originalException]);
}

/// An error that occurs when the storage service is being disposed.
class VaultStorageDisposalError extends VaultStorageError {
  /// Creates a new [VaultStorageDisposalError].
  const VaultStorageDisposalError(super.message, [super.originalException]);
}

/// An error that occurs during the serialization or deserialization of data.
class VaultStorageSerializationError extends VaultStorageError {
  /// Creates a new [VaultStorageSerializationError].
  const VaultStorageSerializationError(super.message, [super.originalException]);
}

/// An error that occurs when an operation is not available on the current platform.
class UnsupportedPlatformError extends VaultStorageError {
  /// Creates a new [UnsupportedPlatformError].
  const UnsupportedPlatformError(super.message, [super.originalException]);
}

/// An error that occurs when attempting to access a custom box that was not registered during init.
class BoxNotFoundError extends VaultStorageError {
  /// Creates a new [BoxNotFoundError].
  const BoxNotFoundError(super.message, [super.originalException]);
}

/// An error that occurs when a key exists in multiple boxes and no specific box is specified.
class AmbiguousKeyError extends VaultStorageError {
  /// The key that exists in multiple boxes.
  final String key;

  /// The names of the boxes where the key was found.
  final List<String> foundInBoxes;

  /// Creates a new [AmbiguousKeyError].
  const AmbiguousKeyError(this.key, this.foundInBoxes, super.message, [super.originalException]);
}
