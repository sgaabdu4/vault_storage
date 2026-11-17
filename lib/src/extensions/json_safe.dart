import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:vault_storage/src/constants/vault_storage_config.dart';
import 'package:vault_storage/src/errors/storage_error.dart';

/// Utility class for safe JSON encoding and decoding with isolate support
abstract final class JsonSafe {
  static const String _corruptedDataHint = 'Consider clearing corrupted data.';

  // Type markers for optimized storage
  static const String _typeMarkerPrefix = '__VST__'; // Vault Storage Type marker
  static const String _stringMarker = '${_typeMarkerPrefix}STR:';
  static const String _intMarker = '${_typeMarkerPrefix}INT:';
  static const String _doubleMarker = '${_typeMarkerPrefix}DBL:';
  static const String _boolMarker = '${_typeMarkerPrefix}BOOL:';
  static const String _jsonMarker = '${_typeMarkerPrefix}JSON:';

  /// Safely encodes an object to JSON with automatic type-based optimization
  static Future<String> encode(Object? value, VaultStorageConfig config) async {
    try {
      // Type-based optimization for primitives
      if (value == null) return '${_jsonMarker}null';

      // String optimization - store directly if small
      if (value is String) {
        if (value.length <= config.primitiveStringThreshold &&
            !value.startsWith(_typeMarkerPrefix)) {
          return '$_stringMarker$value';
        }
        // Large strings go through JSON for consistency
        return await _encodeComplex(value, config);
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
      return await _encodeComplex(value, config);
    } catch (e, stackTrace) {
      Error.throwWithStackTrace(
        VaultStorageSerializationError('Failed to encode object', e),
        stackTrace,
      );
    }
  }

  /// Safely decodes a JSON string with automatic type-based optimization
  static Future<T> decode<T>(String encodedValue, VaultStorageConfig config) async {
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
      final decoded = jsonString.length > config.jsonIsolateThreshold
          ? await compute(_decodeInIsolate, jsonString)
          : json.decode(jsonString);

      // Legacy v2.x compatibility: Handle type coercion for primitives
      return _coerceType<T>(decoded);
    } catch (e, stackTrace) {
      Error.throwWithStackTrace(
        VaultStorageSerializationError('Failed to decode value', _withoutSource(e)),
        stackTrace,
      );
    }
  }

  /// Coerces decoded value to expected type T for legacy v2.x compatibility
  static T _coerceType<T>(Object? value) {
    if (value is T) return value;

    final Object? coerced = switch (T) {
      int => _coerceInt(value),
      double => _coerceDouble(value),
      bool when value is String => value.toLowerCase() == 'true',
      String when value != null => value.toString(),
      _ => value,
    };
    if (coerced is T) return coerced;
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
            'Type mismatch: Cannot parse the stored text as int. $_corruptedDataHint',
            _withoutSource(e),
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
            'Type mismatch: Cannot parse the stored text as double. $_corruptedDataHint',
            _withoutSource(e),
          ),
          stackTrace,
        );
      }
    }
    throw _typeMismatch<double>(value);
  }

  static VaultStorageSerializationError _typeMismatch<T>(Object? value) =>
      VaultStorageSerializationError(
        'Type mismatch: Cannot convert ${value.runtimeType} to type $T. $_corruptedDataHint',
      );

  /// Encodes complex objects (non-primitives) with isolate optimization
  static Future<String> _encodeComplex(Object? value, VaultStorageConfig config) async {
    if (_shouldUseIsolate(value, config)) {
      final jsonResult = await compute(_encodeInIsolate, value);
      return '$_jsonMarker$jsonResult';
    }

    // Small complex objects - encode synchronously
    final jsonResult = json.encode(value);
    return '$_jsonMarker$jsonResult';
  }

  // Helper to estimate if object is large enough for isolate
  static bool _shouldUseIsolate(Object? value, VaultStorageConfig config) {
    if (value == null) return false;
    if (value is String && value.length > config.jsonIsolateThreshold) return true;
    if (value is List && value.length > 100) return true;
    if (value is Map && value.length > 50) return true;
    return false;
  }
}

/// Extension on [String] to provide safe JSON decoding with proper error handling
extension JsonDecodingExtension on String {
  /// Decodes a JSON string safely with automatic isolate optimization
  Future<T> decodeJsonSafely<T>(VaultStorageConfig config) => JsonSafe.decode<T>(this, config);
}

/// Extension on [Object] to provide safe JSON encoding with proper error handling
extension JsonEncodingExtension on Object? {
  /// Encodes an object to JSON safely with automatic isolate optimization
  Future<String> encodeJsonSafely(VaultStorageConfig config) => JsonSafe.encode(this, config);
}

Object _withoutSource(Object error) =>
    error is FormatException ? FormatException(error.message, null, error.offset) : error;

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
      VaultStorageSerializationError('Failed to decode JSON string', _withoutSource(e)),
      stackTrace,
    );
  }
}
