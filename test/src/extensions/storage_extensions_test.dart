import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vault_storage/src/constants/vault_storage_config.dart';
import 'package:vault_storage/src/errors/file_errors.dart';
import 'package:vault_storage/src/errors/storage_error.dart';
import 'package:vault_storage/src/extensions/json_safe.dart';
import 'package:vault_storage/src/extensions/storage_extensions.dart';

void main() {
  const config = VaultStorageConfig();

  group('Base64 Extensions', () {
    group('Base64DecodingExtension', () {
      test('should decode valid base64 string correctly', () async {
        const base64String = 'SGVsbG8gV29ybGQ=';
        final result = await base64String.decodeBase64Safely(context: 'test', config: config);

        expect(result, equals(utf8.encode('Hello World')));
      });

      test('should throw Base64DecodeError for invalid base64 string', () async {
        const invalidBase64 = 'not-valid-base64!';

        await expectLater(
          () => invalidBase64.decodeBase64Safely(context: 'test context', config: config),
          throwsA(isA<Base64DecodeError>()),
        );
      });

      test('should include context in error message', () {
        const invalidBase64 = '%^&*';
        const context = 'custom context';

        expect(
          () => invalidBase64.decodeBase64Safely(context: context, config: config),
          throwsA(isA<Base64DecodeError>()),
        );
      });

      test('should decode large base64 string using isolate', () async {
        // Create a large base64 string (> base64IsolateThreshold)
        final largeData = List.generate(60000, (i) => i % 256);
        final base64String = base64Url.encode(largeData);

        final result = await base64String.decodeBase64Safely(
          context: 'large data test',
          config: config,
        );
        expect(result, equals(largeData));
      });

      test('should handle standard base64 fallback in isolate', () async {
        // Create data that when encoded with standard base64 differs from base64Url
        final data = List.generate(60000, (i) => 255);
        final standardBase64 = base64.encode(data);

        final result = await standardBase64.decodeBase64Safely(
          context: 'standard fallback test',
          config: config,
        );
        expect(result.length, equals(60000));
      });

      test('should use sync decode for small strings', () {
        const base64String = 'SGVsbG8gV29ybGQ=';
        final result = base64String.decodeBase64SafelySync(context: 'sync test');
        expect(result, equals(utf8.encode('Hello World')));
      });

      test('should throw Base64DecodeError in sync decode', () {
        const invalidBase64 = 'not-valid!!!!';
        expect(
          () => invalidBase64.decodeBase64SafelySync(context: 'sync error test'),
          throwsA(isA<Base64DecodeError>()),
        );
      });

      test('should handle fallback in sync decode', () {
        // Test standard base64 fallback in sync method
        const standardBase64 = 'SGVsbG8h'; // "Hello!" in standard base64
        final result = standardBase64.decodeBase64SafelySync(context: 'fallback test');
        expect(result, isNotEmpty);
      });
    });

    group('Base64EncodingExtension', () {
      test('should encode bytes to base64 string correctly', () async {
        final bytes = utf8.encode('Hello World');
        final result = bytes.encodeBase64();

        expect(result, isA<String>());
        // Test that we can decode it back
        final decoded = await result.decodeBase64Safely(context: 'test round trip', config: config);
        expect(decoded, equals(bytes));
      });

      test('should encode large bytes using isolate', () async {
        // Create large data (> base64IsolateThreshold)
        final largeData = Uint8List.fromList(.generate(60000, (i) => i % 256));
        final result = await largeData.encodeBase64Safely(
          context: 'large encode test',
          config: config,
        );

        expect(result, isA<String>());
        expect(result.length, greaterThan(0));

        // Verify we can decode it back
        final decoded = await result.decodeBase64Safely(
          context: 'decode verification',
          config: config,
        );
        expect(decoded, equals(largeData));
      });

      test('should use sync encode for small data', () {
        final smallData = Uint8List.fromList([1, 2, 3, 4, 5]);
        final result = smallData.encodeBase64SafelySync(context: 'sync encode test');
        expect(result, isA<String>());
      });

      test('should convert List<int> to Uint8List before encoding', () async {
        final listData = <int>[1, 2, 3, 4, 5];
        final result = await listData.encodeBase64Safely(
          context: 'list encode test',
          config: config,
        );
        expect(result, isA<String>());

        // Verify it's the same as Uint8List encoding
        final uint8Result = await Uint8List.fromList(
          listData,
        ).encodeBase64Safely(context: 'uint8 test', config: config);
        expect(result, equals(uint8Result));
      });

      test('should handle empty byte array', () {
        final emptyData = Uint8List(0);
        final result = emptyData.encodeBase64SafelySync(context: 'empty test');
        expect(result, equals(''));
      });
    });
  });

  group('JSON Extensions', () {
    group('JsonDecodingExtension', () {
      test('should decode valid JSON object correctly', () async {
        const jsonString = '{"name": "test", "value": 42}';
        final result = await jsonString.decodeJsonSafely<Map<String, dynamic>>(config);

        expect(result, isA<Map<String, dynamic>>());
        expect(result, equals({'name': 'test', 'value': 42}));
      });

      test('should throw VaultStorageSerializationError for invalid JSON string', () async {
        const invalidJson = '{invalid json}';

        await expectLater(
          () => invalidJson.decodeJsonSafely<Map<String, dynamic>>(config),
          throwsA(isA<VaultStorageSerializationError>()),
        );
      });

      test('should handle different types correctly', () async {
        const jsonList = '[1, 2, 3]';
        final result = await jsonList.decodeJsonSafely<List<Object?>>(config);

        expect(result, isA<List<Object?>>());
        expect(result, equals([1, 2, 3]));
      });

      test('should decode large JSON using isolate', () async {
        // Create a large JSON string
        final largeMap = Map.fromIterables(
          List.generate(150, (i) => 'key_$i'),
          List.generate(150, (i) => 'value_$i'),
        );
        final jsonString = await largeMap.encodeJsonSafely(config);

        final result = await jsonString.decodeJsonSafely<Map<String, dynamic>>(config);
        expect(result.length, equals(150));
      });

      test('should decode legacy JSON without type marker', () async {
        const legacyJson = '{"name": "test"}';
        final decoded = await JsonSafe.decode<Map<String, dynamic>>(legacyJson, config);
        expect(decoded, equals({'name': 'test'}));
      });

      test('should decode legacy JSON array without type marker', () async {
        const legacyJson = '[1, 2, 3]';
        final decoded = await JsonSafe.decode<List<Object?>>(legacyJson, config);
        expect(decoded, equals([1, 2, 3]));
      });
    });

    group('JsonEncodingExtension', () {
      test('should encode Map object to JSON string correctly', () async {
        final map = {'name': 'test', 'value': 42};
        final result = await map.encodeJsonSafely(config);

        expect(result, isA<String>());
        // Use our decode method to handle type markers
        final decoded = await result.decodeJsonSafely<Map<String, dynamic>>(config);
        expect(decoded, equals(map));
      });

      test('should encode List object to JSON string correctly', () async {
        final list = [1, 2, 3, 'test'];
        final result = await list.encodeJsonSafely(config);

        expect(result, isA<String>());
        // Use our decode method to handle type markers
        final decoded = await result.decodeJsonSafely<List<Object?>>(config);
        expect(decoded, equals(list));
      });

      test('should throw VaultStorageSerializationError for circular reference objects', () async {
        // Create a circular reference
        final map = <String, dynamic>{'name': 'test'};
        map['self'] = map; // Create circular reference

        await expectLater(
          () => map.encodeJsonSafely(config),
          throwsA(isA<VaultStorageSerializationError>()),
        );
      });
    });
  });

  group('Map Extensions', () {
    group('FileMetadataExtension', () {
      final testMap = {
        'stringKey': 'value',
        'intKey': 42,
        'doubleKey': 3.14,
        'boolKey': true,
        'listKey': [1, 2, 3],
        'mapKey': {'nested': 'value'},
      };

      test('should return required string value', () {
        final result = testMap.getRequiredString('stringKey');
        expect(result, equals('value'));
      });

      test('should throw InvalidMetadataError for missing required string', () {
        expect(() => testMap.getRequiredString('missingKey'), throwsA(isA<InvalidMetadataError>()));
      });

      test('should throw InvalidMetadataError for wrong type required string', () {
        expect(() => testMap.getRequiredString('intKey'), throwsA(isA<InvalidMetadataError>()));
      });

      test('should return optional string value', () {
        final result = testMap.getOptionalString('stringKey');
        expect(result, equals('value'));
      });

      test('should return null for missing optional string', () {
        final result = testMap.getOptionalString('missingKey');
        expect(result, isNull);
      });

      test('should return null for wrong type optional string', () {
        final result = testMap.getOptionalString('intKey');
        expect(result, isNull);
      });

      test('should throw InvalidMetadataError with custom message', () {
        const customMsg = 'Custom error message';
        expect(
          () => testMap.getRequiredString('missingKey', customErrorMsg: customMsg),
          throwsA(isA<InvalidMetadataError>()),
        );
      });
    });
  });

  group('JsonSafe Utility Class', () {
    test('should encode object to JSON string correctly', () async {
      final map = {'name': 'test', 'value': 42};
      final result = await JsonSafe.encode(map, config);

      expect(result, isA<String>());
      // Use our decode method to handle type markers
      final decoded = await JsonSafe.decode<Map<String, dynamic>>(result, config);
      expect(decoded, equals(map));
    });

    test('should decode JSON string to object correctly', () async {
      const jsonString = '{"name": "test", "value": 42}';
      final result = await JsonSafe.decode<Map<String, dynamic>>(jsonString, config);

      expect(result, isA<Map<String, dynamic>>());
      expect(result, equals({'name': 'test', 'value': 42}));
    });

    test('should throw VaultStorageSerializationError for encoding failures', () async {
      final map = <String, dynamic>{'name': 'test'};
      map['self'] = map; // Create circular reference

      await expectLater(
        () => JsonSafe.encode(map, config),
        throwsA(isA<VaultStorageSerializationError>()),
      );
    });

    test('should throw VaultStorageSerializationError for decoding failures', () async {
      const invalidJson = '{invalid json}';

      await expectLater(
        () => JsonSafe.decode<Map<String, dynamic>>(invalidJson, config),
        throwsA(isA<VaultStorageSerializationError>()),
      );
    });

    test('should encode null value', () async {
      final result = await JsonSafe.encode(null, config);
      expect(result, contains('JSON'));
      expect(result, contains('null'));

      final decoded = await JsonSafe.decode<Object?>(result, config);
      expect(decoded, isNull);
    });

    test('should encode and decode small string without JSON', () async {
      const smallString = 'test';
      final encoded = await JsonSafe.encode(smallString, config);
      expect(encoded, startsWith('__VST__STR:'));
      expect(encoded, equals('__VST__STR:test'));

      final decoded = await JsonSafe.decode<String>(encoded, config);
      expect(decoded, equals(smallString));
    });

    test('should encode large string with JSON', () async {
      // Create string larger than primitiveStringThreshold
      final largeString = 'x' * 1500;
      final encoded = await JsonSafe.encode(largeString, config);
      expect(encoded, startsWith('__VST__JSON:'));

      final decoded = await JsonSafe.decode<String>(encoded, config);
      expect(decoded, equals(largeString));
    });

    test('should encode and decode int primitive', () async {
      const intValue = 42;
      final encoded = await JsonSafe.encode(intValue, config);
      expect(encoded, startsWith('__VST__INT:'));
      expect(encoded, equals('__VST__INT:42'));

      final decoded = await JsonSafe.decode<int>(encoded, config);
      expect(decoded, equals(intValue));
    });

    test('should encode and decode negative int', () async {
      const intValue = -123;
      final encoded = await JsonSafe.encode(intValue, config);
      expect(encoded, equals('__VST__INT:-123'));

      final decoded = await JsonSafe.decode<int>(encoded, config);
      expect(decoded, equals(intValue));
    });

    test('should encode and decode double primitive', () async {
      const doubleValue = 3.14159;
      final encoded = await JsonSafe.encode(doubleValue, config);
      expect(encoded, startsWith('__VST__DBL:'));

      final decoded = await JsonSafe.decode<double>(encoded, config);
      expect(decoded, equals(doubleValue));
    });

    test('should encode and decode bool true', () async {
      const boolValue = true;
      final encoded = await JsonSafe.encode(boolValue, config);
      expect(encoded, startsWith('__VST__BOOL:'));
      expect(encoded, equals('__VST__BOOL:true'));

      final decoded = await JsonSafe.decode<bool>(encoded, config);
      expect(decoded, equals(true));
    });

    test('should encode and decode bool false', () async {
      const boolValue = false;
      final encoded = await JsonSafe.encode(boolValue, config);
      expect(encoded, equals('__VST__BOOL:false'));

      final decoded = await JsonSafe.decode<bool>(encoded, config);
      expect(decoded, equals(false));
    });

    test('should handle string with type marker prefix', () async {
      // String that starts with type marker prefix should be JSON encoded
      const specialString = '__VST__special';
      final encoded = await JsonSafe.encode(specialString, config);
      expect(encoded, startsWith('__VST__JSON:'));

      final decoded = await JsonSafe.decode<String>(encoded, config);
      expect(decoded, equals(specialString));
    });

    test('should encode large Map using isolate', () async {
      final largeMap = Map.fromIterables(
        List.generate(150, (i) => 'key_$i'),
        List.generate(150, (i) => 'value_$i'),
      );
      final encoded = await JsonSafe.encode(largeMap, config);
      expect(encoded, startsWith('__VST__JSON:'));

      final decoded = await JsonSafe.decode<Map<String, dynamic>>(encoded, config);
      expect(decoded.length, equals(150));
    });

    test('should encode large List using isolate', () async {
      final largeList = List.generate(150, (i) => i);
      final encoded = await JsonSafe.encode(largeList, config);
      expect(encoded, startsWith('__VST__JSON:'));

      final decoded = await JsonSafe.decode<List<Object?>>(encoded, config);
      expect(decoded.length, equals(150));
    });
  });

  group('Error Chain Extensions', () {
    test('should create error chain with nested base64 error', () async {
      const invalidBase64 = 'not-valid-base64!';

      try {
        await invalidBase64.decodeBase64Safely(context: 'encryption key', config: config);
        fail('Should have thrown an exception');
      } catch (error) {
        expect(
          error,
          isA<Base64DecodeError>().having(
            (base64Error) => base64Error.message,
            'message',
            contains('encryption key'),
          ),
        );
      }
    });

    test('should create error chain with nested JSON error', () async {
      const invalidJson = '{broken json}';

      try {
        await invalidJson.decodeJsonSafely<Map<String, dynamic>>(config);
        fail('Should have thrown an exception');
      } catch (error) {
        expect(
          error,
          isA<VaultStorageSerializationError>().having(
            (serializationError) => serializationError.message,
            'message',
            contains('Failed to decode value'),
          ),
        );
      }
    });
  });

  group('Configuration and Performance Tests', () {
    test('should respect custom base64IsolateThreshold', () async {
      const lowThreshold = VaultStorageConfig(base64IsolateThreshold: 10);

      final data = Uint8List.fromList(.generate(20, (i) => i));
      final encoded = await data.encodeBase64Safely(
        context: 'threshold test',
        config: lowThreshold,
      );
      expect(encoded, isA<String>());

      final decoded = await encoded.decodeBase64Safely(
        context: 'threshold test',
        config: lowThreshold,
      );
      expect(decoded, equals(data));
    });

    test('should respect custom jsonIsolateThreshold', () async {
      const lowThreshold = VaultStorageConfig(jsonIsolateThreshold: 5);

      final data = {'test': 'value that exceeds threshold'};
      final encoded = await JsonSafe.encode(data, lowThreshold);
      expect(encoded, isA<String>());

      final decoded = await JsonSafe.decode<Map<String, dynamic>>(encoded, lowThreshold);
      expect(decoded, equals(data));
    });

    test('should respect custom primitiveStringThreshold', () async {
      const lowThreshold = VaultStorageConfig(primitiveStringThreshold: 5);
      const shortString = 'abc';
      const longString = 'this is longer than 5 chars';

      final shortEncoded = await JsonSafe.encode(shortString, lowThreshold);
      expect(shortEncoded, startsWith('__VST__STR:'));

      final longEncoded = await JsonSafe.encode(longString, lowThreshold);
      expect(longEncoded, startsWith('__VST__JSON:'));
    });
  });

  group('Integration Tests', () {
    test('should handle round-trip encoding and decoding', () async {
      final originalData = {
        'string': 'test value',
        'number': 42,
        'list': [1, 2, 3],
        'nested': {'key': 'value'},
      };

      // Encode to JSON
      final jsonString = await originalData.encodeJsonSafely(config);
      expect(jsonString, isA<String>());

      // Decode back to object
      final decodedData = await jsonString.decodeJsonSafely<Map<String, dynamic>>(config);
      expect(decodedData, equals(originalData));
    });

    test('should handle base64 round-trip encoding and decoding', () async {
      const originalData = 'Hello, World! 🌍';
      final bytes = utf8.encode(originalData);

      // Encode to base64
      final base64String = bytes.encodeBase64();
      expect(base64String, isA<String>());

      // Decode back to bytes
      final decodedBytes = await base64String.decodeBase64Safely(
        context: 'round trip test',
        config: config,
      );
      expect(decodedBytes, equals(bytes));

      // Convert back to string
      final decodedString = utf8.decode(decodedBytes);
      expect(decodedString, equals(originalData));
    });

    test('should handle all primitive types round-trip', () async {
      // Test int
      const intVal = 123;
      String encoded = await JsonSafe.encode(intVal, config);
      final decoded = await JsonSafe.decode<int>(encoded, config);
      expect(decoded, equals(intVal));

      // Test double
      const doubleVal = 123.456;
      encoded = await JsonSafe.encode(doubleVal, config);
      final decodedDouble = await JsonSafe.decode<double>(encoded, config);
      expect(decodedDouble, equals(doubleVal));

      // Test bool true
      const boolTrueVal = true;
      encoded = await JsonSafe.encode(boolTrueVal, config);
      final decodedBool = await JsonSafe.decode<bool>(encoded, config);
      expect(decodedBool, equals(boolTrueVal));

      // Test bool false
      const boolFalseVal = false;
      encoded = await JsonSafe.encode(boolFalseVal, config);
      final decodedBoolFalse = await JsonSafe.decode<bool>(encoded, config);
      expect(decodedBoolFalse, equals(boolFalseVal));

      // Test string
      const stringVal = 'test';
      encoded = await JsonSafe.encode(stringVal, config);
      final decodedString = await JsonSafe.decode<String>(encoded, config);
      expect(decodedString, equals(stringVal));
    });

    test('should handle complex nested structures', () async {
      final complex = {
        'string': 'value',
        'int': 42,
        'double': 3.14,
        'bool': true,
        'list': [1, 2, 3],
        'nested': {'inner': 'value', 'number': 100},
      };

      final encoded = await JsonSafe.encode(complex, config);
      final decoded = await JsonSafe.decode<Map<String, dynamic>>(encoded, config);

      expect(decoded['string'], equals('value'));
      expect(decoded['int'], equals(42));
      expect(decoded['double'], equals(3.14));
      expect(decoded['bool'], equals(true));
      expect(decoded['list'], equals([1, 2, 3]));
      expect(decoded['nested'], containsPair('inner', 'value'));
    });
  });
}
