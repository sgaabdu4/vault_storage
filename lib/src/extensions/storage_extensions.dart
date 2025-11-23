import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:vault_storage/src/constants/config.dart';
import 'package:vault_storage/src/errors/file_errors.dart';
import 'package:vault_storage/src/errors/storage_error.dart';

/// Request class for Base64 decode operations in isolates
class _Base64DecodeRequest {
  final String data;
  final String context;

  const _Base64DecodeRequest(this.data, this.context);
}

/// Request class for Base64 encode operations in isolates
class _Base64EncodeRequest {
  final Uint8List data;
  final String context;

  const _Base64EncodeRequest(this.data, this.context);
}

/// Isolate function for decoding large Base64 strings
Uint8List _decodeBase64InIsolate(_Base64DecodeRequest request) {
  try {
    try {
      return base64Url.decode(request.data);
    } catch (e) {
      // Fallback to standard base64 if base64Url fails
      return base64.decode(request.data);
    }
  } catch (e) {
    throw Exception('Base64 decode failed in isolate for ${request.context}: $e');
  }
}

/// Isolate function for encoding large binary data to Base64
String _encodeBase64InIsolate(_Base64EncodeRequest request) {
  try {
    return base64Url.encode(request.data);
  } catch (e) {
    throw Exception('Base64 encode failed in isolate for ${request.context}: $e');
  }
}

/// Extension on [String] to provide safe base64 decoding with proper error handling
extension Base64DecodingExtension on String {
  /// Decodes a base64Url string safely with performance optimizations
  ///
  /// Performance features:
  /// - Uses isolates for large base64 strings (>50KB) to prevent UI blocking
  /// - Optimized error handling with context information
  /// - Supports both standard base64 and base64Url encoding
  ///
  /// Example:
  /// ```dart
  /// try {
  ///   final bytes = await base64String.decodeBase64Safely(context: 'encryption key');
  ///   print('Decoded ${bytes.length} bytes successfully');
  /// } catch (e) {
  ///   print('Decode failed: ${e.message}');
  /// }
  /// ```
  Future<Uint8List> decodeBase64Safely({required String context}) async {
    try {
      // For large base64 strings, use isolate to prevent UI blocking
      if (length > VaultStorageConfig.base64IsolateThreshold) {
        // ~37KB of original data
        return await compute(_decodeBase64InIsolate, _Base64DecodeRequest(this, context));
      }

      // Small strings - decode synchronously for better performance
      try {
        return base64Url.decode(this);
      } catch (e) {
        // Fallback to standard base64 if base64Url fails
        return base64.decode(this);
      }
    } catch (e) {
      throw Base64DecodeError(context, e);
    }
  }

  /// Synchronous version for backwards compatibility and small data
  ///
  /// Use this only for small base64 strings or when you're sure about the size.
  /// For unknown sizes, prefer [decodeBase64Safely] async version.
  Uint8List decodeBase64SafelySync({required String context}) {
    try {
      try {
        return base64Url.decode(this);
      } catch (e) {
        // Fallback to standard base64 if base64Url fails
        return base64.decode(this);
      }
    } catch (e) {
      throw Base64DecodeError(context, e);
    }
  }
}

/// Extension on [Uint8List] and [List<int>] to provide safe base64 encoding with performance optimizations
extension Base64EncodingExtension on List<int> {
  /// Encodes bytes to base64Url string safely with performance optimizations
  ///
  /// Performance features:
  /// - Uses isolates for large binary data (>50KB) to prevent UI blocking
  /// - Optimized for both small and large data sizes
  /// - Uses base64Url encoding for URL-safe output
  ///
  /// Example:
  /// ```dart
  /// final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
  /// final encoded = await bytes.encodeBase64Safely(context: 'file content');
  /// print('Encoded: $encoded');
  /// ```
  Future<String> encodeBase64Safely({required String context}) async {
    try {
      // Convert to Uint8List if needed for consistency
      final uint8List = this is Uint8List ? this as Uint8List : Uint8List.fromList(this);

      // For large binary data, use isolate to prevent UI blocking
      if (length > VaultStorageConfig.base64IsolateThreshold) {
        // ~50KB threshold
        return await compute(_encodeBase64InIsolate, _Base64EncodeRequest(uint8List, context));
      }

      // Small data - encode synchronously for better performance
      return base64Url.encode(this);
    } catch (e) {
      throw Base64EncodeError(context, e);
    }
  }

  /// Synchronous version for backwards compatibility and small data
  ///
  /// Use this only for small binary data or when you're sure about the size.
  /// For unknown sizes, prefer [encodeBase64Safely] async version.
  String encodeBase64SafelySync({required String context}) {
    try {
      return base64Url.encode(this);
    } catch (e) {
      throw Base64EncodeError(context, e);
    }
  }

  /// Legacy method for backwards compatibility - encodes bytes to a base64Url string
  ///
  /// @deprecated Use [encodeBase64Safely] for better performance and error handling
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

/// Utility class for safe JSON encoding and decoding with isolate support
class JsonSafe {
  JsonSafe._(); // Private constructor to prevent instantiation

  // Thresholds for optimization decisions
  static int get _isolateThreshold => VaultStorageConfig.jsonIsolateThreshold;
  static int get _primitiveStringThreshold => VaultStorageConfig.primitiveStringThreshold;

  // Type markers for optimized storage
  static const String _typeMarkerPrefix = '__VST__'; // Vault Storage Type marker
  static const String _stringMarker = '${_typeMarkerPrefix}STR:';
  static const String _intMarker = '${_typeMarkerPrefix}INT:';
  static const String _doubleMarker = '${_typeMarkerPrefix}DBL:';
  static const String _boolMarker = '${_typeMarkerPrefix}BOOL:';
  static const String _jsonMarker = '${_typeMarkerPrefix}JSON:';

  /// Safely encodes an object to JSON with automatic type-based optimization
  ///
  /// Performance optimizations:
  /// - Primitives (String, int, double, bool) bypass JSON encoding
  /// - Small objects use synchronous encoding
  /// - Large objects use isolate-based encoding to prevent UI blocking
  /// Throws [StorageSerializationError] if encoding fails.
  static Future<String> encode(Object? value) async {
    try {
      // Type-based optimization for primitives
      if (value == null) return '${_jsonMarker}null';

      // String optimization - store directly if small
      if (value is String) {
        if (value.length <= _primitiveStringThreshold && !value.startsWith(_typeMarkerPrefix)) {
          return '$_stringMarker$value';
        }
        // Large strings go through JSON for consistency
        return await _encodeComplex(value);
      }

      // Numeric types - store directly
      if (value is int) {
        return '$_intMarker$value';
      }

      if (value is double) {
        return '$_doubleMarker$value';
      }

      // Boolean - store directly
      if (value is bool) {
        return '$_boolMarker$value';
      }

      // Complex types (Map, List, custom objects) - use JSON
      return await _encodeComplex(value);
    } catch (e) {
      throw StorageSerializationError('Failed to encode object', e);
    }
  }

  /// Safely decodes a JSON string with automatic type-based optimization
  ///
  /// Automatically detects and handles:
  /// - Type-optimized primitives
  /// - Small JSON strings (sync decoding)
  /// - Large JSON strings (isolate-based decoding)
  /// Throws [StorageSerializationError] if decoding fails.
  static Future<T> decode<T>(String encodedValue) async {
    try {
      // Check for type markers (primitive optimizations)
      if (encodedValue.startsWith(_stringMarker)) {
        final value = encodedValue.substring(_stringMarker.length);
        return _coerceType<T>(value);
      }

      if (encodedValue.startsWith(_intMarker)) {
        final value = int.parse(encodedValue.substring(_intMarker.length));
        return _coerceType<T>(value);
      }

      if (encodedValue.startsWith(_doubleMarker)) {
        final value = double.parse(encodedValue.substring(_doubleMarker.length));
        return _coerceType<T>(value);
      }

      if (encodedValue.startsWith(_boolMarker)) {
        final value = encodedValue.substring(_boolMarker.length) == 'true';
        return _coerceType<T>(value);
      }

      // Handle JSON-encoded values
      String jsonString;
      if (encodedValue.startsWith(_jsonMarker)) {
        jsonString = encodedValue.substring(_jsonMarker.length);
      } else {
        // Legacy support - assume it's JSON if no marker
        jsonString = encodedValue;
      }

      // Size-based optimization for JSON decoding
      final decoded = jsonString.length > _isolateThreshold
          ? await compute(_decodeInIsolate, jsonString)
          : json.decode(jsonString);

      // Legacy v2.x compatibility: Handle type coercion for primitives
      // v2.x stored primitives as JSON strings without type markers
      return _coerceType<T>(decoded);
    } catch (e) {
      throw StorageSerializationError('Failed to decode value', e);
    }
  }

  /// Coerces decoded value to expected type T for legacy v2.x compatibility
  ///
  /// v2.x stored primitives as JSON-encoded strings without type markers.
  /// Simple type coercion only - complex migrations should be handled by users.
  static T _coerceType<T>(dynamic value) {
    // If value is already the correct type, return it
    if (value is T) return value;

    // Simple primitive conversions for v2.x compatibility
    if (T == int && value is String) {
      try {
        return int.parse(value) as T;
      } catch (e) {
        throw StorageSerializationError(
          'Type mismatch: Cannot parse "$value" as int. '
          'Consider clearing corrupted data.',
          e,
        );
      }
    }
    if (T == int && value is num) return value.toInt() as T;

    if (T == double && value is String) {
      try {
        return double.parse(value) as T;
      } catch (e) {
        throw StorageSerializationError(
          'Type mismatch: Cannot parse "$value" as double. '
          'Consider clearing corrupted data.',
          e,
        );
      }
    }
    if (T == double && value is num) return value.toDouble() as T;

    if (T == bool && value is String) return (value.toLowerCase() == 'true') as T;
    if (T == String && value != null) return value.toString() as T;

    // Type mismatch - throw clear error
    throw StorageSerializationError(
      'Type mismatch: Cannot convert "$value" (${value.runtimeType}) to type $T. '
      'Consider clearing corrupted data.',
    );
  }

  /// Encodes complex objects (non-primitives) with isolate optimization
  static Future<String> _encodeComplex(Object? value) async {
    if (_shouldUseIsolate(value)) {
      final jsonResult = await compute(_encodeInIsolate, value);
      return '$_jsonMarker$jsonResult';
    }

    // Small complex objects - encode synchronously
    final jsonResult = json.encode(value);
    return '$_jsonMarker$jsonResult';
  }

  // Helper to estimate if object is large enough for isolate
  static bool _shouldUseIsolate(Object? value) {
    if (value == null) return false;
    if (value is String && value.length > _isolateThreshold) return true;
    if (value is List && value.length > 100) return true;
    if (value is Map && value.length > 50) return true;
    return false;
  }
}

/// Extension on [String] to provide safe JSON decoding with proper error handling
extension JsonDecodingExtension on String {
  /// Decodes a JSON string safely with automatic isolate optimization
  ///
  /// For small JSON strings, uses synchronous decoding for better performance.
  /// For large JSON strings, uses isolate-based decoding to prevent UI blocking.
  /// Throws [StorageSerializationError] if decoding fails.
  ///
  /// Example:
  /// ```dart
  /// try {
  ///   final map = await jsonString.decodeJsonSafely<Map<String, dynamic>>();
  ///   print('Decoded successfully: $map');
  /// } catch (e) {
  ///   print('Decode failed: ${e.message}');
  /// }
  /// ```
  Future<T> decodeJsonSafely<T>() async {
    return JsonSafe.decode<T>(this);
  }
}

/// Extension on [Object] to provide safe JSON encoding with proper error handling
extension JsonEncodingExtension on Object? {
  /// Encodes an object to JSON safely with automatic isolate optimization
  ///
  /// For small objects, uses synchronous encoding for better performance.
  /// For large objects, uses isolate-based encoding to prevent UI blocking.
  /// Throws [StorageSerializationError] if encoding fails.
  ///
  /// Example:
  /// ```dart
  /// try {
  ///   final jsonString = await object.encodeJsonSafely();
  ///   print('Encoded successfully: $jsonString');
  /// } catch (e) {
  ///   print('Encode failed: ${e.message}');
  /// }
  /// ```
  Future<String> encodeJsonSafely() async {
    return JsonSafe.encode(this);
  }
}

// Top-level isolate functions for JSON operations
String _encodeInIsolate(Object? value) {
  try {
    return json.encode(value);
  } catch (e) {
    throw StorageSerializationError('Failed to encode object to JSON', e);
  }
}

/// Generic JSON decode in isolate - returns decoded value
/// The caller must handle type casting
Object? _decodeInIsolate(String jsonString) {
  try {
    return json.decode(jsonString);
  } catch (e) {
    throw StorageSerializationError('Failed to decode JSON string', e);
  }
}
