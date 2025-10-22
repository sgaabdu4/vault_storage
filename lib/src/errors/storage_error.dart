/// A sealed class representing the various errors that can occur within the vault storage.
///
/// Using a sealed class allows for exhaustive pattern matching on error types,
/// ensuring that all potential failure cases are handled explicitly.
sealed class StorageError implements Exception {
  /// Creates a new [StorageError] with a descriptive [message] and an optional
  /// [originalException] that caused the error.
  const StorageError(this.message, [this.originalException]);

  /// A descriptive message explaining the nature of the error.
  final String message;

  /// The original exception or error object that was caught, if any.
  final Object? originalException;
}

/// An error that occurs during the initialization of the vault storage.
///
/// This could happen if there are issues with setting up Hive, accessing secure
/// storage, or generating encryption keys.
class StorageInitializationError extends StorageError {
  /// Creates a new [StorageInitializationError].
  const StorageInitializationError(super.message, [super.originalException]);
}

/// An error that occurs when attempting to read data from storage.
///
/// This might be due to a non-existent key, a corrupted box, or issues with
/// decryption.
class StorageReadError extends StorageError {
  /// Creates a new [StorageReadError].
  const StorageReadError(super.message, [super.originalException]);
}

/// An error that occurs when attempting to write data to storage.
///
/// This could be caused by serialization issues, a full disk, or problems with
/// the underlying storage mechanism.
class StorageWriteError extends StorageError {
  /// Creates a new [StorageWriteError].
  const StorageWriteError(super.message, [super.originalException]);
}

/// An error that occurs when attempting to delete data from storage.
///
/// This might happen if the key does not exist or if there are permissions issues.
class StorageDeleteError extends StorageError {
  /// Creates a new [StorageDeleteError].
  const StorageDeleteError(super.message, [super.originalException]);
}

/// An error that occurs when the storage service is being disposed.
class StorageDisposalError extends StorageError {
  /// Creates a new [StorageDisposalError].
  const StorageDisposalError(super.message, [super.originalException]);
}

/// An error that occurs during the serialization or deserialization of data.
///
/// This is typically thrown when an object cannot be converted to a format suitable
/// for storage, such as JSON.
class StorageSerializationError extends StorageError {
  /// Creates a new [StorageSerializationError].
  const StorageSerializationError(super.message, [super.originalException]);
}

/// An error that occurs when attempting to access a custom box that was not registered during init.
///
/// Custom boxes must be defined when creating the VaultStorage instance.
class BoxNotFoundError extends StorageError {
  /// Creates a new [BoxNotFoundError].
  const BoxNotFoundError(super.message, [super.originalException]);
}

/// An error that occurs when a key exists in multiple boxes and no specific box is specified.
///
/// When calling get() without specifying a box parameter, if the key exists in more than
/// one box (including default normal/secure boxes and custom boxes), this error is thrown
/// to prevent ambiguity.
class AmbiguousKeyError extends StorageError {
  /// The key that exists in multiple boxes.
  final String key;

  /// The names of the boxes where the key was found.
  final List<String> foundInBoxes;

  /// Creates a new [AmbiguousKeyError].
  const AmbiguousKeyError(this.key, this.foundInBoxes, super.message, [super.originalException]);
}
