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
  } catch (e, stackTrace) {
    Error.throwWithStackTrace(
      Exception('Base64 decode failed in isolate for ${request.context}: $e'),
      stackTrace,
    );
  }
}

/// Isolate function for encoding large binary data to Base64
String _encodeBase64InIsolate(_Base64EncodeRequest request) {
  try {
    return base64Url.encode(request.data);
  } catch (e, stackTrace) {
    Error.throwWithStackTrace(
      Exception('Base64 encode failed in isolate for ${request.context}: $e'),
      stackTrace,
    );
  }
}

/// Extension on [String] to provide safe base64 decoding with proper error handling
extension Base64DecodingExtension on String {
  /// Decodes a base64Url string safely with performance optimizations
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
    } catch (e, stackTrace) {
      Error.throwWithStackTrace(Base64DecodeError(context, e), stackTrace);
    }
  }

  /// Synchronous version for backwards compatibility and small data
  Uint8List decodeBase64SafelySync({required String context}) {
    try {
      try {
        return base64Url.decode(this);
      } catch (e) {
        // Fallback to standard base64 if base64Url fails
        return base64.decode(this);
      }
    } catch (e, stackTrace) {
      Error.throwWithStackTrace(Base64DecodeError(context, e), stackTrace);
    }
  }
}

/// Extension on [Uint8List] and [List<int>] to provide safe base64 encoding with performance optimizations
extension Base64EncodingExtension on List<int> {
  /// Encodes bytes to base64Url string safely with performance optimizations
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
    } catch (e, stackTrace) {
      Error.throwWithStackTrace(Base64EncodeError(context, e), stackTrace);
    }
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
  @Deprecated('Use encodeBase64Safely for better performance and error handling')
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
    } catch (e, stackTrace) {
      Error.throwWithStackTrace(
        VaultStorageSerializationError('Failed to encode object', e),
        stackTrace,
      );
    }
  }

  /// Safely decodes a JSON string with automatic type-based optimization
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
      return _coerceType<T>(decoded);
    } catch (e, stackTrace) {
      Error.throwWithStackTrace(
        VaultStorageSerializationError('Failed to decode value', e),
        stackTrace,
      );
    }
  }

  /// Coerces decoded value to expected type T for legacy v2.x compatibility
  static T _coerceType<T>(Object? value) {
    if (value is T) return value;

    if (T == int) return _coerceInt(value) as T;
    if (T == double) return _coerceDouble(value) as T;
    if (T == bool && value is String) return (value.toLowerCase() == 'true') as T;
    if (T == String && value != null) return value.toString() as T;
    throw _typeMismatch<T>(value);
  }

  static int _coerceInt(Object? value) {
    if (value is num) return value.toInt();
    if (value is String) {
      try {
        return .parse(value);
      } catch (e, stackTrace) {
        Error.throwWithStackTrace(
          VaultStorageSerializationError(
            'Type mismatch: Cannot parse "$value" as int. '
            'Consider clearing corrupted data.',
            e,
          ),
          stackTrace,
        );
      }
    }
    throw _typeMismatch<int>(value);
  }

  static double _coerceDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      try {
        return .parse(value);
      } catch (e, stackTrace) {
        Error.throwWithStackTrace(
          VaultStorageSerializationError(
            'Type mismatch: Cannot parse "$value" as double. '
            'Consider clearing corrupted data.',
            e,
          ),
          stackTrace,
        );
      }
    }
    throw _typeMismatch<double>(value);
  }

  static VaultStorageSerializationError _typeMismatch<T>(Object? value) =>
      VaultStorageSerializationError(
        'Type mismatch: Cannot convert "$value" (${value.runtimeType}) to type $T. '
        'Consider clearing corrupted data.',
      );

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
  Future<T> decodeJsonSafely<T>() async {
    return JsonSafe.decode<T>(this);
  }
}

/// Extension on [Object] to provide safe JSON encoding with proper error handling
extension JsonEncodingExtension on Object? {
  /// Encodes an object to JSON safely with automatic isolate optimization
  Future<String> encodeJsonSafely() async {
    return JsonSafe.encode(this);
  }
}

// Top-level isolate functions for JSON operations
String _encodeInIsolate(Object? value) {
  try {
    return json.encode(value);
  } catch (e, stackTrace) {
    Error.throwWithStackTrace(
      VaultStorageSerializationError('Failed to encode object to JSON', e),
      stackTrace,
    );
  }
}

/// Generic JSON decode in isolate - returns decoded value
Object? _decodeInIsolate(String jsonString) {
  try {
    return json.decode(jsonString);
  } catch (e, stackTrace) {
    Error.throwWithStackTrace(
      VaultStorageSerializationError('Failed to decode JSON string', e),
      stackTrace,
    );
  }
}
