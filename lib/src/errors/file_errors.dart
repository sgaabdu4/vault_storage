import 'package:vault_storage/src/errors/storage_error.dart';

/// An error that occurs during base64 decoding operations for file data.
class Base64DecodeError extends VaultStorageReadError {
  /// Creates a new [Base64DecodeError].
  Base64DecodeError(String context, Object? originalException)
    : super('Failed to decode base64 for $context', originalException);
}

/// An error that occurs during base64 encoding operations for file data.
class Base64EncodeError extends VaultStorageWriteError {
  /// Creates a new [Base64EncodeError].
  Base64EncodeError(String context, Object? originalException)
    : super('Failed to encode base64 for $context', originalException);
}

/// An error that occurs when a file is not found.
class FileNotFoundError extends VaultStorageReadError {
  /// Creates a new [FileNotFoundError].
  FileNotFoundError(String fileId, String location)
    : super('File not found: ID $fileId in $location');
}

/// An error that occurs when file metadata is invalid or incomplete.
class InvalidMetadataError extends VaultStorageReadError {
  /// Creates a new [InvalidMetadataError].
  InvalidMetadataError(String missingField) : super('Invalid file metadata: missing $missingField');
}

/// An error that occurs when a cryptographic key is not found in secure storage.
class KeyNotFoundError extends VaultStorageReadError {
  /// Creates a new [KeyNotFoundError].
  KeyNotFoundError(String keyName) : super('Encryption key not found in secure storage: $keyName');
}
