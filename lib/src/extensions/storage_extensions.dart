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
  Either<Base64DecodeError, Uint8List> decodeBase64Safely(
      {required String context}) {
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
