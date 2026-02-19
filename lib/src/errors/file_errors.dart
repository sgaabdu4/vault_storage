import 'package:vault_storage/src/errors/storage_error.dart';

/// An error that occurs during base64 decoding operations for file data.
///
/// This is thrown when attempting to decode a base64 string (for file content,
/// encryption keys, nonces, etc.) and the operation fails due to invalid encoding.
class Base64DecodeError extends VaultStorageReadError {
  /// Creates a new [Base64DecodeError].
  ///
  /// The [context] parameter specifies what was being decoded (e.g., "file content", "encryption key").
  Base64DecodeError(String context, Object? originalException)
      : super('Failed to decode base64 for $context', originalException);
}

/// An error that occurs during base64 encoding operations for file data.
///
/// This is thrown when attempting to encode binary data to base64 string
/// and the operation fails.
class Base64EncodeError extends VaultStorageWriteError {
  /// Creates a new [Base64EncodeError].
  ///
  /// The [context] parameter specifies what was being encoded (e.g., "file content", "binary data").
  Base64EncodeError(String context, Object? originalException)
      : super('Failed to encode base64 for $context', originalException);
}

/// An error that occurs when a file is not found.
///
/// This can happen when trying to retrieve a file from storage (Hive or file system)
/// and it doesn't exist.
class FileNotFoundError extends VaultStorageReadError {
  /// Creates a new [FileNotFoundError].
  ///
  /// The [fileId] is the identifier used to locate the file.
  /// The [location] describes where the file was being searched (e.g., "Hive", "file system").
  FileNotFoundError(String fileId, String location)
      : super('File not found: ID $fileId in $location');
}

/// An error that occurs when file metadata is invalid or incomplete.
///
/// This is thrown when the metadata required to access a file is missing critical
/// information like a file path or identifier.
class InvalidMetadataError extends VaultStorageReadError {
  /// Creates a new [InvalidMetadataError].
  ///
  /// The [missingField] specifies which field was missing or invalid in the metadata.
  InvalidMetadataError(String missingField) : super('Invalid file metadata: missing $missingField');
}

/// An error that occurs when a cryptographic key is not found in secure storage.
///
/// This can happen when trying to access an encryption key that should exist in
/// secure storage but doesn't, possibly due to manual deletion or corruption.
class KeyNotFoundError extends VaultStorageReadError {
  /// Creates a new [KeyNotFoundError].
  ///
  /// The [keyName] is the identifier used to locate the key in secure storage.
  KeyNotFoundError(String keyName) : super('Encryption key not found in secure storage: $keyName');
}
