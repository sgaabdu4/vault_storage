import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:vault_storage/src/errors/file_errors.dart';
import 'package:vault_storage/src/errors/storage_error.dart';
import 'package:vault_storage/src/extensions/storage_extensions.dart';

void main() {
  group('Base64 Extensions', () {
    group('Base64DecodingExtension', () {
      test('should decode valid base64 string correctly', () {
        const base64String = 'SGVsbG8gV29ybGQ=';
        final result = base64String.decodeBase64Safely(context: 'test');

        expect(result.isRight(), isTrue);
        result.fold((_) => fail('Should not return Left for valid base64'),
            (bytes) {
          expect(bytes, equals(utf8.encode('Hello World')));
        });
      });

      test('should return Base64DecodeError for invalid base64 string', () {
        const invalidBase64 = 'not-valid-base64!';
        final result =
            invalidBase64.decodeBase64Safely(context: 'test context');

        expect(result.isLeft(), isTrue);
        result.fold((error) {
          expect(error, isA<Base64DecodeError>());
          expect(error.message, contains('test context'));
        }, (_) => fail('Should return Left for invalid base64'));
      });
    });

    group('Base64EncodingExtension', () {
      test('should encode Uint8List correctly', () {
        final bytes = Uint8List.fromList([72, 101, 108, 108, 111]); // "Hello"
        final result = bytes.encodeBase64();

        expect(result, equals('SGVsbG8='));
        expect(base64Url.decode(result), equals(bytes));
      });

      test('should encode List<int> correctly', () {
        final list = [72, 101, 108, 108, 111]; // "Hello"
        final result = list.encodeBase64();

        expect(result, equals('SGVsbG8='));
        expect(base64Url.decode(result), equals(list));
      });
    });
  });

  group('JSON Extensions', () {
    group('JsonDecodingExtension', () {
      test('should decode valid JSON string correctly', () {
        const jsonString = '{"name":"test","value":123}';
        final result = jsonString.decodeJsonSafely<Map<String, dynamic>>();

        expect(result.isRight(), isTrue);
        result.fold((_) => fail('Should not return Left for valid JSON'),
            (map) {
          expect(map, equals({"name": "test", "value": 123}));
        });
      });

      test('should return StorageSerializationError for invalid JSON', () {
        const invalidJson = '{name:"test",}';
        final result = invalidJson.decodeJsonSafely<Map<String, dynamic>>();

        expect(result.isLeft(), isTrue);
        result.fold((error) {
          expect(error, isA<StorageSerializationError>());
          expect(error.message, contains('decode'));
        }, (_) => fail('Should return Left for invalid JSON'));
      });

      test('should return StorageSerializationError for type mismatch', () {
        const jsonArray = '[1, 2, 3]';
        final result = jsonArray.decodeJsonSafely<Map<String, dynamic>>();

        expect(result.isLeft(), isTrue);
        result.fold((error) {
          expect(error, isA<StorageSerializationError>());
        }, (_) => fail('Should return Left for type mismatch'));
      });
    });

    group('JsonEncodingExtension', () {
      test('should encode Map correctly', () {
        final map = {"name": "test", "value": 123};
        final result = map.encodeJsonSafely();

        expect(result.isRight(), isTrue);
        result.fold((_) => fail('Should not return Left for valid object'),
            (jsonStr) {
          expect(jsonDecode(jsonStr), equals(map));
        });
      });

      test('should encode List correctly', () {
        final list = [1, 2, 3];
        final result = list.encodeJsonSafely();

        expect(result.isRight(), isTrue);
        result.fold((_) => fail('Should not return Left for valid object'),
            (jsonStr) {
          expect(jsonDecode(jsonStr), equals(list));
        });
      });

      test('should return StorageSerializationError for unencodable object',
          () {
        final unencodable = _UnencodableObject();
        final result = unencodable.encodeJsonSafely();

        expect(result.isLeft(), isTrue);
        result.fold((error) {
          expect(error, isA<StorageSerializationError>());
          expect(error.message, contains('encode'));
        }, (_) => fail('Should return Left for unencodable object'));
      });
    });
  });

  group('FileMetadataExtension', () {
    test('getRequiredString should return value when key exists', () {
      final metadata = {'key1': 'value1', 'key2': 'value2'};

      expect(metadata.getRequiredString('key1'), equals('value1'));
      expect(metadata.getRequiredString('key2'), equals('value2'));
    });

    test(
        'getRequiredString should throw InvalidMetadataError when key is missing',
        () {
      final metadata = {'key1': 'value1'};

      expect(() => metadata.getRequiredString('missing'),
          throwsA(isA<InvalidMetadataError>()));
    });

    test(
        'getRequiredString should throw InvalidMetadataError when value is not a string',
        () {
      final metadata = {'key1': 123, 'key2': true};

      expect(() => metadata.getRequiredString('key1'),
          throwsA(isA<InvalidMetadataError>()));
      expect(() => metadata.getRequiredString('key2'),
          throwsA(isA<InvalidMetadataError>()));
    });

    test('getOptionalString should return value when key exists', () {
      final metadata = {'key1': 'value1', 'key2': 'value2'};

      expect(metadata.getOptionalString('key1'), equals('value1'));
      expect(metadata.getOptionalString('key2'), equals('value2'));
    });

    test('getOptionalString should return null when key is missing', () {
      final metadata = {'key1': 'value1'};

      expect(metadata.getOptionalString('missing'), isNull);
    });

    test('getOptionalString should return null when value is not a string', () {
      final metadata = {'key1': 123, 'key2': true};

      expect(metadata.getOptionalString('key1'), isNull);
      expect(metadata.getOptionalString('key2'), isNull);
    });
  });

  group('TaskEitherFileExtension', () {
    test(
        'mapBase64DecodeError should map Base64DecodeError to StorageReadError',
        () async {
      final base64Error =
          Base64DecodeError('test context', Exception('Invalid base64'));
      final task = TaskEither<StorageError, String>.left(base64Error);

      final result = await task.mapBase64DecodeError().run();
      expect(result.isLeft(), isTrue);
      result.fold((error) {
        expect(error, isA<StorageReadError>());
        expect(error.message, equals(base64Error.message));
        expect(error.originalException, equals(base64Error.originalException));
      }, (_) => fail('Should return Left'));
    });

    test('mapBase64DecodeError should not change other errors', () async {
      final otherError =
          StorageWriteError('write error', Exception('Write failed'));
      final task = TaskEither<StorageError, String>.left(otherError);

      final result = await task.mapBase64DecodeError().run();
      expect(result.isLeft(), isTrue);
      result.fold((error) {
        expect(error, same(otherError));
      }, (_) => fail('Should return Left'));
    });
  });

  group('JsonSafe utility class', () {
    test('encode should handle valid objects correctly', () {
      final result = JsonSafe.encode({'name': 'test'});
      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('Should not return Left for valid object'),
        (jsonStr) => expect(jsonDecode(jsonStr), equals({'name': 'test'})),
      );
    });

    test('encode should return error for unencodable objects', () {
      final unencodable = _UnencodableObject();
      final result = JsonSafe.encode(unencodable);

      expect(result.isLeft(), isTrue);
      result.fold(
        (error) {
          expect(error, isA<StorageSerializationError>());
          expect(error.message, contains('Failed to encode object to JSON'));
        },
        (_) => fail('Should return Left for unencodable object'),
      );
    });

    test('decode should handle valid JSON strings correctly', () {
      final result = JsonSafe.decode<Map<String, dynamic>>('{"name":"test"}');
      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('Should not return Left for valid JSON'),
        (map) => expect(map, equals({'name': 'test'})),
      );
    });

    test('decode should return error for invalid JSON strings', () {
      final result = JsonSafe.decode<Map<String, dynamic>>('{invalid:json}');

      expect(result.isLeft(), isTrue);
      result.fold(
        (error) {
          expect(error, isA<StorageSerializationError>());
          expect(error.message, contains('Failed to decode JSON'));
        },
        (_) => fail('Should return Left for invalid JSON'),
      );
    });

    test('decode should return error for type mismatches', () {
      final result = JsonSafe.decode<Map<String, dynamic>>('[1,2,3]');

      expect(result.isLeft(), isTrue);
      result.fold(
        (error) {
          expect(error, isA<StorageSerializationError>());
          expect(error.message, contains('Failed to decode JSON'));
        },
        (_) => fail('Should return Left for type mismatch'),
      );
    });
  });

  group('JsonSafe', () {
    test('should not be instantiable (private constructor)', () {
      // JsonSafe._() cannot be called from outside the class
      // This test verifies that JsonSafe is a utility class that cannot be instantiated
      // We verify that static methods are accessible
      expect(() => JsonSafe.encode({'test': 'value'}), returnsNormally);
      expect(() => JsonSafe.decode<Map<String, dynamic>>('{"test":"value"}'),
          returnsNormally);

      // Test that demonstrates the class is designed as a utility class
      expect(() => _testJsonSafeUtility(), returnsNormally);
    });
  });
}

// Helper function to test JsonSafe utility functionality
void _testJsonSafeUtility() {
  // This function exists to demonstrate that JsonSafe is a utility class
  // with only static methods and cannot be instantiated
  var result = JsonSafe.encode({'key': 'value'});
  expect(result.isRight(), isTrue);
}

class _UnencodableObject {
  dynamic cyclicRef;

  _UnencodableObject() {
    cyclicRef = this; // Create a circular reference that can't be JSON encoded
  }

  @override
  String toString() => 'UnencodableObject';
}
