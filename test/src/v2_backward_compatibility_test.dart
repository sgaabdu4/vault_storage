import 'package:flutter_test/flutter_test.dart';
import 'package:vault_storage/src/errors/storage_error.dart';
import 'package:vault_storage/src/extensions/storage_extensions.dart';

/// Tests for v2.x backward compatibility
///
/// v2.x stored all values as JSON-encoded strings without type markers.
/// v3.0 must properly decode these legacy formats and coerce to correct types.
void main() {
  group('v2.x Legacy Format Compatibility', () {
    test('should decode v2.x int stored as JSON string', () async {
      // v2.x format: json.encode(1234567890) = "1234567890"
      const v2xIntValue = '"1234567890"';

      final result = await JsonSafe.decode<int>(v2xIntValue);

      expect(result, 1234567890);
      expect(result, isA<int>());
    });

    test('should decode v2.x double stored as JSON string', () async {
      // v2.x format: json.encode(3.14159) = "3.14159"
      const v2xDoubleValue = '"3.14159"';

      final result = await JsonSafe.decode<double>(v2xDoubleValue);

      expect(result, 3.14159);
      expect(result, isA<double>());
    });

    test('should decode v2.x bool stored as JSON string', () async {
      // v2.x format: json.encode(true) = "true"
      const v2xBoolValueTrue = '"true"';
      const v2xBoolValueFalse = '"false"';

      final resultTrue = await JsonSafe.decode<bool>(v2xBoolValueTrue);
      final resultFalse = await JsonSafe.decode<bool>(v2xBoolValueFalse);

      expect(resultTrue, true);
      expect(resultTrue, isA<bool>());
      expect(resultFalse, false);
      expect(resultFalse, isA<bool>());
    });

    test('should decode v2.x String stored as JSON string', () async {
      // v2.x format: json.encode("hello world") = "\"hello world\""
      const v2xStringValue = '"hello world"';

      final result = await JsonSafe.decode<String>(v2xStringValue);

      expect(result, 'hello world');
      expect(result, isA<String>());
    });

    test('should decode v2.x List stored as JSON string', () async {
      // v2.x format: json.encode([1, 2, 3]) = "[1,2,3]"
      const v2xListValue = '[1,2,3]';

      final result = await JsonSafe.decode<List<dynamic>>(v2xListValue);

      expect(result, [1, 2, 3]);
      expect(result, isA<List<dynamic>>());
    });

    test('should decode v2.x Map stored as JSON string', () async {
      // v2.x format: json.encode({"key": "value"}) = '{"key":"value"}'
      const v2xMapValue = '{"key":"value"}';

      final result = await JsonSafe.decode<Map<String, dynamic>>(v2xMapValue);

      expect(result, {'key': 'value'});
      expect(result, isA<Map<String, dynamic>>());
    });

    test('should handle numeric type conversions', () async {
      // v2.x might store int as double or vice versa
      const intAsDouble = '42.0';
      const doubleAsInt = '42';

      final intResult = await JsonSafe.decode<int>(intAsDouble);
      final doubleResult = await JsonSafe.decode<double>(doubleAsInt);

      expect(intResult, 42);
      expect(intResult, isA<int>());
      expect(doubleResult, 42.0);
      expect(doubleResult, isA<double>());
    });

    test('should handle null values from v2.x', () async {
      const v2xNullValue = 'null';

      final result = await JsonSafe.decode<String?>(v2xNullValue);

      expect(result, isNull);
    });
  });

  group('v3.0 Type Marker Format (should still work)', () {
    test('should decode v3.0 int with type marker', () async {
      // v3.0 format: __VST__INT:1234567890
      const v3IntValue = '__VST__INT:1234567890';

      final result = await JsonSafe.decode<int>(v3IntValue);

      expect(result, 1234567890);
      expect(result, isA<int>());
    });

    test('should decode v3.0 double with type marker', () async {
      // v3.0 format: __VST__DBL:3.14159
      const v3DoubleValue = '__VST__DBL:3.14159';

      final result = await JsonSafe.decode<double>(v3DoubleValue);

      expect(result, 3.14159);
      expect(result, isA<double>());
    });

    test('should decode v3.0 bool with type marker', () async {
      // v3.0 format: __VST__BOOL:true / __VST__BOOL:false
      const v3BoolValueTrue = '__VST__BOOL:true';
      const v3BoolValueFalse = '__VST__BOOL:false';

      final resultTrue = await JsonSafe.decode<bool>(v3BoolValueTrue);
      final resultFalse = await JsonSafe.decode<bool>(v3BoolValueFalse);

      expect(resultTrue, true);
      expect(resultFalse, false);
    });

    test('should decode v3.0 String with type marker', () async {
      // v3.0 format: __VST__STR:hello world
      const v3StringValue = '__VST__STR:hello world';

      final result = await JsonSafe.decode<String>(v3StringValue);

      expect(result, 'hello world');
      expect(result, isA<String>());
    });
  });

  // These tests verify basic type conversions work, not complex migrations
  group('Basic Type Conversions', () {
    test('should handle numeric conversions (int ↔ double)', () async {
      const intAsDouble = '42.0';
      const doubleAsInt = '42';

      final intResult = await JsonSafe.decode<int>(intAsDouble);
      final doubleResult = await JsonSafe.decode<double>(doubleAsInt);

      expect(intResult, 42);
      expect(intResult, isA<int>());
      expect(doubleResult, 42.0);
      expect(doubleResult, isA<double>());
    });

    test('should convert int to String when reading with wrong type', () async {
      // v3.0 format: __VST__INT:1234567890
      const v3IntValue = '__VST__INT:1234567890';

      // User mistakenly reads as String (e.g., changed their code)
      final result = await JsonSafe.decode<String>(v3IntValue);

      expect(result, '1234567890');
      expect(result, isA<String>());
    });

    test('should convert String to int when type marker indicates int', () async {
      // v3.0 format: __VST__STR:123
      const v3StringValue = '__VST__STR:123';

      // User wants to read as int (e.g., changed data format)
      final result = await JsonSafe.decode<int>(v3StringValue);

      expect(result, 123);
      expect(result, isA<int>());
    });

    test('should throw clear error for invalid type conversions', () async {
      // ISO 8601 DateTime string cannot be converted to int
      const dateTimeString = '"2025-10-27T09:21:58.047024"';

      expect(
        () async => JsonSafe.decode<int>(dateTimeString),
        throwsA(isA<StorageSerializationError>()),
      );
    });
  });
}
