import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:vault_storage/src/constants/vault_storage_config.dart';
import 'package:vault_storage/src/errors/file_errors.dart';

Uint8List _decodeBase64Lenient(String data) {
  try {
    return base64Url.decode(data);
  } on FormatException {
    return base64.decode(data);
  }
}

Uint8List _decodeBase64InIsolate(String data) => _decodeBase64Lenient(data);

String _encodeBase64InIsolate(Uint8List data) => base64Url.encode(data);

Future<Uint8List> _decodeLargeBase64(String data, String label) async {
  try {
    return await compute(_decodeBase64InIsolate, data);
  } catch (e, stackTrace) {
    Error.throwWithStackTrace(Base64DecodeError(label, e), stackTrace);
  }
}

Future<String> _encodeLargeBase64(Uint8List data, String label) async {
  try {
    return await compute(_encodeBase64InIsolate, data);
  } catch (e, stackTrace) {
    Error.throwWithStackTrace(Base64EncodeError(label, e), stackTrace);
  }
}

/// Extension on [String] to provide safe base64 decoding with proper error handling
extension Base64DecodingExtension on String {
  /// Decodes a base64Url string safely with performance optimizations
  Future<Uint8List> decodeBase64Safely({required String context}) async {
    if (length > VaultStorageConfig.base64IsolateThreshold) {
      return _decodeLargeBase64(this, context);
    }
    return decodeBase64SafelySync(context: context);
  }

  /// Synchronous version for backwards compatibility and small data
  Uint8List decodeBase64SafelySync({required String context}) {
    try {
      return _decodeBase64Lenient(this);
    } catch (e, stackTrace) {
      Error.throwWithStackTrace(Base64DecodeError(context, e), stackTrace);
    }
  }
}

/// Extension on [Uint8List] and [List<int>] to provide safe base64 encoding with performance optimizations
extension Base64EncodingExtension on List<int> {
  /// Encodes bytes to base64Url string safely with performance optimizations
  Future<String> encodeBase64Safely({required String context}) async {
    if (length > VaultStorageConfig.base64IsolateThreshold) {
      final Uint8List bytes = switch (this) {
        final Uint8List list => list,
        _ => .fromList(this),
      };
      return _encodeLargeBase64(bytes, context);
    }
    return encodeBase64SafelySync(context: context);
  }

  /// Synchronous version for backwards compatibility and small data
  String encodeBase64SafelySync({required String context}) {
    try {
      return base64Url.encode(this);
    } catch (e, stackTrace) {
      Error.throwWithStackTrace(Base64EncodeError(context, e), stackTrace);
    }
  }

  /// Legacy method for backwards compatibility - encodes bytes to a base64Url string
  String encodeBase64() => base64Url.encode(this);
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
