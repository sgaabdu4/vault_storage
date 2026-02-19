/// A sealed class representing the various errors that can occur within the vault storage.
///
/// Using a sealed class allows for exhaustive pattern matching on error types,
/// ensuring that all potential failure cases are handled explicitly.
sealed class VaultStorageError implements Exception {
  /// Creates a new [VaultStorageError] with a descriptive [message] and an optional
  /// [originalException] that caused the error.
  const VaultStorageError(this.message, [this.originalException]);

  /// A descriptive message explaining the nature of the error.
  final String message;

  /// The original exception or error object that was caught, if any.
  final Object? originalException;

  @override
  String toString() {
    final buffer = StringBuffer('$runtimeType: $message');
    if (originalException != null) {
      buffer.write(' (caused by: $originalException)');
    }
    return buffer.toString();
  }
}

/// An error that occurs during the initialization of the vault storage.
///
/// This could happen if there are issues with setting up Hive, accessing secure
/// storage, or generating encryption keys.
class VaultStorageInitializationError extends VaultStorageError {
  /// Creates a new [VaultStorageInitializationError].
  const VaultStorageInitializationError(super.message, [super.originalException]);
}

/// An error that occurs when attempting to read data from storage.
///
/// This might be due to a non-existent key, a corrupted box, or issues with
/// decryption.
class VaultStorageReadError extends VaultStorageError {
  /// Creates a new [VaultStorageReadError].
  const VaultStorageReadError(super.message, [super.originalException]);
}

/// An error that occurs when attempting to write data to storage.
///
/// This could be caused by serialization issues, a full disk, or problems with
/// the underlying storage mechanism.
class VaultStorageWriteError extends VaultStorageError {
  /// Creates a new [VaultStorageWriteError].
  const VaultStorageWriteError(super.message, [super.originalException]);
}

/// An error that occurs when attempting to delete data from storage.
///
/// This might happen if the key does not exist or if there are permissions issues.
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
///
/// This is typically thrown when an object cannot be converted to a format suitable
/// for storage, such as JSON.
class VaultStorageSerializationError extends VaultStorageError {
  /// Creates a new [VaultStorageSerializationError].
  const VaultStorageSerializationError(super.message, [super.originalException]);
}

/// An error that occurs when attempting to access a custom box that was not registered during init.
///
/// Custom boxes must be defined when creating the VaultStorage instance.
class BoxNotFoundError extends VaultStorageError {
  /// Creates a new [BoxNotFoundError].
  const BoxNotFoundError(super.message, [super.originalException]);
}

/// An error that occurs when a key exists in multiple boxes and no specific box is specified.
///
/// When calling get() without specifying a box parameter, if the key exists in more than
/// one box (including default normal/secure boxes and custom boxes), this error is thrown
/// to prevent ambiguity.
class AmbiguousKeyError extends VaultStorageError {
  /// The key that exists in multiple boxes.
  final String key;

  /// The names of the boxes where the key was found.
  final List<String> foundInBoxes;

  /// Creates a new [AmbiguousKeyError].
  const AmbiguousKeyError(this.key, this.foundInBoxes, super.message, [super.originalException]);
}

// ---------------------------------------------------------------------------
// Deprecated type aliases for backward compatibility.
// These will be removed in a future major release.
// ---------------------------------------------------------------------------

/// Use [VaultStorageError] instead.
@Deprecated('Use VaultStorageError instead. Will be removed in v4.0.0.')
typedef StorageError = VaultStorageError;

/// Use [VaultStorageInitializationError] instead.
@Deprecated('Use VaultStorageInitializationError instead. Will be removed in v4.0.0.')
typedef StorageInitializationError = VaultStorageInitializationError;

/// Use [VaultStorageReadError] instead.
@Deprecated('Use VaultStorageReadError instead. Will be removed in v4.0.0.')
typedef StorageReadError = VaultStorageReadError;

/// Use [VaultStorageWriteError] instead.
@Deprecated('Use VaultStorageWriteError instead. Will be removed in v4.0.0.')
typedef StorageWriteError = VaultStorageWriteError;

/// Use [VaultStorageDeleteError] instead.
@Deprecated('Use VaultStorageDeleteError instead. Will be removed in v4.0.0.')
typedef StorageDeleteError = VaultStorageDeleteError;

/// Use [VaultStorageDisposalError] instead.
@Deprecated('Use VaultStorageDisposalError instead. Will be removed in v4.0.0.')
typedef StorageDisposalError = VaultStorageDisposalError;

/// Use [VaultStorageSerializationError] instead.
@Deprecated('Use VaultStorageSerializationError instead. Will be removed in v4.0.0.')
typedef StorageSerializationError = VaultStorageSerializationError;
