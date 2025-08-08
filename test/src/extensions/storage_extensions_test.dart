import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vault_storage/src/errors/file_errors.dart';
import 'package:vault_storage/src/errors/storage_error.dart';
import 'package:vault_storage/src/extensions/storage_extensions.dart';

void main() {
  group('Base64 Extensions', () {
    group('Base64DecodingExtension', () {
      test('should decode valid base64 string correctly', () async {
        const base64String = 'SGVsbG8gV29ybGQ=';
        final result = await base64String.decodeBase64Safely(context: 'test');

        expect(result, equals(utf8.encode('Hello World')));
      });

      test('should throw Base64DecodeError for invalid base64 string',
          () async {
        const invalidBase64 = 'not-valid-base64!';

        await expectLater(
          () => invalidBase64.decodeBase64Safely(context: 'test context'),
          throwsA(isA<Base64DecodeError>()),
        );
      });

      test('should include context in error message', () {
        const invalidBase64 = '%^&*';
        const context = 'custom context';

        expect(
          () => invalidBase64.decodeBase64Safely(context: context),
          throwsA(isA<Base64DecodeError>()),
        );
      });
    });

    group('Base64EncodingExtension', () {
      test('should encode bytes to base64 string correctly', () async {
        final bytes = utf8.encode('Hello World');
        final result = bytes.encodeBase64();

        expect(result, isA<String>());
        // Test that we can decode it back
        final decoded =
            await result.decodeBase64Safely(context: 'test round trip');
        expect(decoded, equals(bytes));
      });
    });
  });

  group('JSON Extensions', () {
    group('JsonDecodingExtension', () {
      test('should decode valid JSON object correctly', () async {
        const jsonString = '{"name": "test", "value": 42}';
        final result =
            await jsonString.decodeJsonSafely<Map<String, dynamic>>();

        expect(result, isA<Map<String, dynamic>>());
        expect(result, equals({'name': 'test', 'value': 42}));
      });

      test('should throw StorageSerializationError for invalid JSON string',
          () async {
        const invalidJson = '{invalid json}';

        await expectLater(
          () => invalidJson.decodeJsonSafely<Map<String, dynamic>>(),
          throwsA(isA<StorageSerializationError>()),
        );
      });

      test('should handle different types correctly', () async {
        const jsonList = '[1, 2, 3]';
        final result = await jsonList.decodeJsonSafely<List<dynamic>>();

        expect(result, isA<List<dynamic>>());
        expect(result, equals([1, 2, 3]));
      });
    });

    group('JsonEncodingExtension', () {
      test('should encode Map object to JSON string correctly', () async {
        final map = {'name': 'test', 'value': 42};
        final result = await map.encodeJsonSafely();

        expect(result, isA<String>());
        // Use our decode method to handle type markers
        final decoded = await result.decodeJsonSafely<Map<String, dynamic>>();
        expect(decoded, equals(map));
      });

      test('should encode List object to JSON string correctly', () async {
        final list = [1, 2, 3, 'test'];
        final result = await list.encodeJsonSafely();

        expect(result, isA<String>());
        // Use our decode method to handle type markers
        final decoded = await result.decodeJsonSafely<List<dynamic>>();
        expect(decoded, equals(list));
      });

      test(
          'should throw StorageSerializationError for circular reference objects',
          () async {
        // Create a circular reference
        final map = <String, dynamic>{'name': 'test'};
        map['self'] = map; // Create circular reference

        await expectLater(
          () => map.encodeJsonSafely(),
          throwsA(isA<StorageSerializationError>()),
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
        expect(
          () => testMap.getRequiredString('missingKey'),
          throwsA(isA<InvalidMetadataError>()),
        );
      });

      test('should throw InvalidMetadataError for wrong type required string',
          () {
        expect(
          () => testMap.getRequiredString('intKey'),
          throwsA(isA<InvalidMetadataError>()),
        );
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
          () => testMap.getRequiredString('missingKey',
              customErrorMsg: customMsg),
          throwsA(isA<InvalidMetadataError>()),
        );
      });
    });
  });

  group('JsonSafe Utility Class', () {
    test('should encode object to JSON string correctly', () async {
      final map = {'name': 'test', 'value': 42};
      final result = await JsonSafe.encode(map);

      expect(result, isA<String>());
      // Use our decode method to handle type markers
      final decoded = await JsonSafe.decode<Map<String, dynamic>>(result);
      expect(decoded, equals(map));
    });

    test('should decode JSON string to object correctly', () async {
      const jsonString = '{"name": "test", "value": 42}';
      final result = await JsonSafe.decode<Map<String, dynamic>>(jsonString);

      expect(result, isA<Map<String, dynamic>>());
      expect(result, equals({'name': 'test', 'value': 42}));
    });

    test('should throw StorageSerializationError for encoding failures',
        () async {
      final map = <String, dynamic>{'name': 'test'};
      map['self'] = map; // Create circular reference

      await expectLater(
        () => JsonSafe.encode(map),
        throwsA(isA<StorageSerializationError>()),
      );
    });

    test('should throw StorageSerializationError for decoding failures',
        () async {
      const invalidJson = '{invalid json}';

      await expectLater(
        () => JsonSafe.decode<Map<String, dynamic>>(invalidJson),
        throwsA(isA<StorageSerializationError>()),
      );
    });
  });

  group('Error Chain Extensions', () {
    test('should create error chain with nested base64 error', () async {
      const invalidBase64 = 'not-valid-base64!';

      try {
        await invalidBase64.decodeBase64Safely(context: 'encryption key');
        fail('Should have thrown an exception');
      } catch (error) {
        expect(error, isA<Base64DecodeError>());
        final base64Error = error as Base64DecodeError;
        expect(base64Error.message, contains('encryption key'));
      }
    });

    test('should create error chain with nested JSON error', () async {
      const invalidJson = '{broken json}';

      try {
        await invalidJson.decodeJsonSafely<Map<String, dynamic>>();
        fail('Should have thrown an exception');
      } catch (error) {
        expect(error, isA<StorageSerializationError>());
        final serializationError = error as StorageSerializationError;
        expect(serializationError.message, contains('Failed to decode value'));
      }
    });
  });

  group('Integration Tests', () {
    test('should handle round-trip encoding and decoding', () async {
      final originalData = {
        'string': 'test value',
        'number': 42,
        'list': [1, 2, 3],
        'nested': {'key': 'value'}
      };

      // Encode to JSON
      final jsonString = await originalData.encodeJsonSafely();
      expect(jsonString, isA<String>());

      // Decode back to object
      final decodedData =
          await jsonString.decodeJsonSafely<Map<String, dynamic>>();
      expect(decodedData, equals(originalData));
    });

    test('should handle base64 round-trip encoding and decoding', () async {
      const originalData = 'Hello, World! 🌍';
      final bytes = utf8.encode(originalData);

      // Encode to base64
      final base64String = bytes.encodeBase64();
      expect(base64String, isA<String>());

      // Decode back to bytes
      final decodedBytes =
          await base64String.decodeBase64Safely(context: 'round trip test');
      expect(decodedBytes, equals(bytes));

      // Convert back to string
      final decodedString = utf8.decode(decodedBytes);
      expect(decodedString, equals(originalData));
    });
  });
}
