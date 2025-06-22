import 'dart:convert';
import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';
import 'package:vault_storage/src/errors/file_errors.dart';
import 'package:vault_storage/src/errors/storage_error.dart';

/// Extension on [String] to provide safe base64 decoding with proper error handling
extension Base64DecodingExtension on String {
  /// Decodes a base64Url string safely, returning Either<Base64DecodeError, Uint8List>
  ///
  /// - The left side contains a [Base64DecodeError] if decoding fails
  /// - The right side contains the successfully decoded bytes
  ///
  /// Example:
  /// ```dart
  /// final result = base64String.decodeBase64Safely(context: 'encryption key');
  /// result.fold(
  ///   (error) => print('Decode failed: ${error.message}'),
  ///   (bytes) => print('Decoded ${bytes.length} bytes successfully')
  /// );
  /// ```
  Either<Base64DecodeError, Uint8List> decodeBase64Safely({required String context}) {
    try {
      final decoded = base64Url.decode(this);
      return right(decoded);
    } catch (e) {
      return left(Base64DecodeError(context, e));
    }
  }
}

/// Extension on [Uint8List] and [List<int>] to provide safe base64 encoding
extension Base64EncodingExtension on List<int> {
  /// Encodes bytes to a base64Url string safely
  ///
  /// This method doesn't use Either since base64 encoding doesn't typically fail
  /// with valid input bytes, but it provides a consistent interface.
  String encodeBase64() {
    return base64Url.encode(this);
  }
}

/// Extension on Maps to provide safer access to file metadata
extension FileMetadataExtension on Map<String, dynamic> {
  /// Gets a string value from the metadata, throwing an [InvalidMetadataError] if it's missing
  String getRequiredString(String key, {String? customErrorMsg}) {
    final value = this[key];
    if (value == null || value is! String) {
      throw InvalidMetadataError(customErrorMsg ?? key);
    }
    return value;
  }

  /// Gets a string value from the metadata, returning null if it's missing
  String? getOptionalString(String key) {
    final value = this[key];
    if (value == null || value is! String) {
      return null;
    }
    return value;
  }
}

/// Extension for TaskEither to handle common file operation patterns
extension TaskEitherFileExtension<R> on TaskEither<StorageError, R> {
  /// Maps a Base64DecodeError to a StorageReadError
  TaskEither<StorageError, R> mapBase64DecodeError() {
    return mapLeft((error) {
      if (error is Base64DecodeError) {
        return StorageReadError(error.message, error.originalException);
      }
      return error;
    });
  }
}

/// Utility class for safe JSON encoding and decoding
class JsonSafe {
  JsonSafe._(); // Private constructor to prevent instantiation

  /// Safely encodes an object to JSON, returning Either<StorageSerializationError, String>
  ///
  /// - The left side contains a [StorageSerializationError] if encoding fails
  /// - The right side contains the successfully encoded JSON string
  static Either<StorageSerializationError, String> encode(Object? value) {
    try {
      final jsonString = json.encode(value);
      return right(jsonString);
    } catch (e) {
      return left(StorageSerializationError('Failed to encode object to JSON', e));
    }
  }

  /// Safely decodes a JSON string, returning Either<StorageSerializationError, T>
  ///
  /// - The left side contains a [StorageSerializationError] if decoding fails
  /// - The right side contains the successfully decoded object of type T
  static Either<StorageSerializationError, T> decode<T>(String jsonString) {
    try {
      final decoded = json.decode(jsonString) as T;
      return right(decoded);
    } catch (e) {
      return left(StorageSerializationError('Failed to decode JSON string', e));
    }
  }
}

/// Extension on [String] to provide safe JSON decoding with proper error handling
extension JsonDecodingExtension on String {
  /// Decodes a JSON string safely, returning Either<StorageSerializationError, T>
  ///
  /// - The left side contains a [StorageSerializationError] if decoding fails
  /// - The right side contains the successfully decoded object of type T
  ///
  /// Example:
  /// ```dart
  /// final result = jsonString.decodeJsonSafely<Map<String, dynamic>>();
  /// result.fold(
  ///   (error) => print('Decode failed: ${error.message}'),
  ///   (map) => print('Decoded successfully: $map')
  /// );
  /// ```
  Either<StorageSerializationError, T> decodeJsonSafely<T>() {
    return JsonSafe.decode<T>(this);
  }
}

/// Extension on [Object] to provide safe JSON encoding with proper error handling
extension JsonEncodingExtension on Object? {
  /// Encodes an object to JSON safely, returning Either<StorageSerializationError, String>
  ///
  /// - The left side contains a [StorageSerializationError] if encoding fails
  /// - The right side contains the successfully encoded JSON string
  ///
  /// Example:
  /// ```dart
  /// final result = object.encodeJsonSafely();
  /// result.fold(
  ///   (error) => print('Encode failed: ${error.message}'),
  ///   (jsonString) => print('Encoded successfully: $jsonString')
  /// );
  /// ```
  Either<StorageSerializationError, String> encodeJsonSafely() {
    return JsonSafe.encode(this);
  }
}
