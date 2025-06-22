// test/unit/vault_storage/extension_integration_test.dart
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mockito/mockito.dart';
import 'package:vault_storage/src/enum/storage_box_type.dart';
import 'package:vault_storage/src/errors/errors.dart';
import 'package:vault_storage/src/extensions/storage_extensions.dart';
import '../../test_context.dart';

void main() {
  final ctx = TestContext();

  setUp(ctx.setUpCommon);
  tearDown(ctx.tearDownCommon);

  group('Extension Method Integration', () {
    test('should use decodeJsonSafely for JSON decoding', () async {
      const key = 'test_key';
      const jsonString = '{"name":"test"}';
      when(ctx.mockNormalBox.get(key)).thenReturn(jsonString);

      final result =
          await ctx.vaultStorage.get<Map<String, dynamic>>(BoxType.normal, key);

      expect(result.isRight(), isTrue);
      expect(result.getOrElse((_) => {}), equals({"name": "test"}));
    });

    test('should use encodeJsonSafely for JSON encoding', () async {
      const key = 'test_key';
      final value = {"name": "test"};
      when(ctx.mockNormalBox.put(any, any)).thenAnswer((_) async => unit);

      final result = await ctx.vaultStorage.set(BoxType.normal, key, value);

      expect(result.isRight(), isTrue);
      verify(ctx.mockNormalBox.put(key, '{"name":"test"}')).called(1);
    });

    test('should handle metadata with getRequiredString', () async {
      final testMetadata = {
        'fileId': 'test-id',
        'filePath': '/test/path',
        'secureKeyName': 'test-key-name'
      };

      // Test that no exceptions are thrown when using getRequiredString
      expect(testMetadata.getRequiredString('fileId'), equals('test-id'));
      expect(testMetadata.getRequiredString('filePath'), equals('/test/path'));
      expect(testMetadata.getRequiredString('secureKeyName'),
          equals('test-key-name'));

      // Should throw when key is missing
      expect(() => testMetadata.getRequiredString('missingKey'),
          throwsA(isA<InvalidMetadataError>()));
    });

    test('should handle metadata with getOptionalString', () async {
      final testMetadata = {
        'fileId': 'test-id',
        'filePath': '/test/path',
        'nullValue': null,
        'numberValue': 123
      };

      // Test getOptionalString behavior
      expect(testMetadata.getOptionalString('fileId'), equals('test-id'));
      expect(testMetadata.getOptionalString('filePath'), equals('/test/path'));
      expect(testMetadata.getOptionalString('missingKey'), isNull);
      expect(testMetadata.getOptionalString('nullValue'), isNull);
      expect(testMetadata.getOptionalString('numberValue'), isNull);
    });

    test('should handle Base64 encoding/decoding through extensions', () {
      final testBytes = Uint8List.fromList([1, 2, 3, 4, 5]);

      // Test encoding
      final encoded = testBytes.encodeBase64();
      expect(encoded, isA<String>());

      // Test decoding with extension
      final decodedResult = encoded.decodeBase64Safely(context: 'test');
      expect(decodedResult.isRight(), isTrue);
      decodedResult.fold((_) => fail('Should not return Left for valid base64'),
          (bytes) => expect(bytes, equals(testBytes)));

      // Test invalid base64 handling
      final invalidResult =
          'invalid!base64'.decodeBase64Safely(context: 'test');
      expect(invalidResult.isLeft(), isTrue);
      invalidResult.fold((error) => expect(error, isA<Base64DecodeError>()),
          (_) => fail('Should return Left for invalid base64'));
    });
  });
}
