import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vault_storage/src/constants/storage_keys.dart';
import 'package:vault_storage/src/errors/errors.dart';
import 'package:vault_storage/src/vault_storage_impl.dart';

import '../mocks.dart';
import '../test_context.dart';

void main() {
  group('VaultStorageImpl - Additional Coverage Tests', () {
    late TestContext testContext;

    setUpAll(() {
      MocksHelper.registerFallbackValues();
    });

    setUp(() {
      testContext = TestContext();
      testContext.setUpCommon();
    });

    tearDown(() {
      testContext.tearDownCommon();
    });

    group('Custom Boxes - Initialization', () {
      test('should handle custom storage directory', () async {
        final storage = testContext.createStorage(storageDirectory: 'my_custom_dir');

        final base64Key = base64Encode(Uint8List(32));
        when(
          () => testContext.mockSecureStorage.read(key: StorageKeys.secureKey),
        ).thenAnswer((_) async => base64Key);

        await storage.init();

        expect(storage.isVaultStorageReady, isTrue);
      });

      test('should handle empty custom boxes list', () async {
        final tempDir = Directory.systemTemp.createTempSync('vault_empty_boxes_test_');
        addTearDown(() async {
          await Hive.close();
          if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
        });
        final storage = testContext.createStorage(customBoxes: [], storageDirectory: tempDir.path);

        final base64Key = base64Encode(Uint8List(32));
        when(
          () => testContext.mockSecureStorage.read(key: StorageKeys.secureKey),
        ).thenAnswer((_) async => base64Key);

        await storage.init();

        expect(storage.isVaultStorageReady, isTrue);
        expect(storage.customBoxes.isEmpty, isTrue);
      });
    });

    group('Error Handling - Get Operations', () {
      test('should throw BoxNotFoundError when getting from non-existent box', () async {
        when(
          () => testContext.mockSecureStorage.read(key: StorageKeys.secureKey),
        ).thenAnswer((_) async => base64Encode(Uint8List(32)));

        await testContext.vaultStorage.init();

        expect(
          () => testContext.vaultStorage.get<String>('key', box: 'nonexistent'),
          throwsA(isA<BoxNotFoundError>()),
        );
      });

      test('should handle get with null result', () async {
        when(() => testContext.mockNormalBox.get('missing')).thenReturn(null);
        when(() => testContext.mockNormalBox.containsKey('missing')).thenReturn(false);
        when(() => testContext.mockSecureBox.containsKey('missing')).thenReturn(false);
        when(() => testContext.mockNormalFilesBox.containsKey('missing')).thenReturn(false);
        when(() => testContext.mockSecureFilesBox.containsKey('missing')).thenReturn(false);

        final result = await testContext.vaultStorage.get<String>('missing');

        expect(result, isNull);
      });
    });

    group('Error Handling - Save Operations', () {
      test('should throw BoxNotFoundError when saving to non-existent custom box', () async {
        await testContext.vaultStorage.init();

        expect(
          () => testContext.vaultStorage.saveNormal(key: 'key', value: 'value', box: 'nonexistent'),
          throwsA(isA<BoxNotFoundError>()),
        );
      });

      test('should throw BoxNotFoundError when saving secure to non-existent custom box', () async {
        await testContext.vaultStorage.init();

        expect(
          () => testContext.vaultStorage.saveSecure(key: 'key', value: 'value', box: 'nonexistent'),
          throwsA(isA<BoxNotFoundError>()),
        );
      });
    });

    group('Error Handling - Delete Operations', () {
      test('should throw BoxNotFoundError when deleting from non-existent custom box', () async {
        await testContext.vaultStorage.init();

        expect(
          () => testContext.vaultStorage.delete('key', box: 'nonexistent'),
          throwsA(isA<BoxNotFoundError>()),
        );
      });

      test('should delete from all boxes when no box specified', () async {
        when(() => testContext.mockNormalBox.containsKey('shared')).thenReturn(true);
        when(() => testContext.mockSecureBox.containsKey('shared')).thenReturn(true);
        when(() => testContext.mockNormalBox.delete('shared')).thenAnswer((_) async {});
        when(() => testContext.mockSecureBox.delete('shared')).thenAnswer((_) async {});

        await testContext.vaultStorage.delete('shared');

        verify(() => testContext.mockNormalBox.delete('shared')).called(1);
        verify(() => testContext.mockSecureBox.delete('shared')).called(1);
      });
    });

    group('Error Handling - Clear Operations', () {
      test('should clear normal box successfully', () async {
        when(() => testContext.mockNormalBox.clear()).thenAnswer((_) async => 0);

        await testContext.vaultStorage.clearNormal();

        verify(() => testContext.mockNormalBox.clear()).called(1);
      });

      test('should clear secure box successfully', () async {
        when(() => testContext.mockSecureBox.clear()).thenAnswer((_) async => 0);

        await testContext.vaultStorage.clearSecure();

        verify(() => testContext.mockSecureBox.clear()).called(1);
      });

      test('should clear all boxes successfully', () async {
        when(() => testContext.mockNormalBox.clear()).thenAnswer((_) async => 0);
        when(() => testContext.mockSecureBox.clear()).thenAnswer((_) async => 0);

        await testContext.vaultStorage.clearAll(includeFiles: false);

        verify(() => testContext.mockNormalBox.clear()).called(1);
        verify(() => testContext.mockSecureBox.clear()).called(1);
      });
    });

    group('File Operations - Error Handling', () {
      test('should throw BoxNotFoundError when saving file to non-existent box', () async {
        await testContext.vaultStorage.init();

        expect(
          () => testContext.vaultStorage.saveNormalFile(
            key: 'file',
            fileBytes: .fromList([1, 2, 3]),
            originalFileName: 'test.txt',
            box: 'nonexistent',
          ),
          throwsA(isA<BoxNotFoundError>()),
        );
      });

      test('should throw BoxNotFoundError when getting file from non-existent box', () async {
        await testContext.vaultStorage.init();

        expect(
          () => testContext.vaultStorage.getFile('file', box: 'nonexistent'),
          throwsA(isA<BoxNotFoundError>()),
        );
      });

      test('should throw BoxNotFoundError when deleting file from non-existent box', () async {
        await testContext.vaultStorage.init();

        expect(
          () => testContext.vaultStorage.deleteFile('file', box: 'nonexistent'),
          throwsA(isA<BoxNotFoundError>()),
        );
      });

      test('should handle null file metadata when getting file', () async {
        when(() => testContext.mockNormalFilesBox.containsKey('missing')).thenReturn(false);

        final result = await testContext.vaultStorage.getFile('missing', isSecure: false);

        expect(result, isNull);
      });
    });

    group('Encryption Key Management', () {
      test('should generate new key when none exists', () async {
        when(
          () => testContext.mockSecureStorage.read(key: StorageKeys.secureKey),
        ).thenAnswer((_) async => null);
        when(
          () => testContext.mockSecureStorage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          ),
        ).thenAnswer((_) async {});
        when(() => testContext.mockUuid.v4()).thenReturn('test-uuid');

        final secureKey = await testContext.vaultStorage.getOrCreateSecureKey();

        expect(secureKey, isNotEmpty);
        expect(secureKey.length, equals(32)); // AES-256 requires 32 bytes
        verify(
          () => testContext.mockSecureStorage.write(
            key: StorageKeys.secureKey,
            value: any(named: 'value'),
          ),
        ).called(1);
      });

      test('should retrieve existing key', () async {
        final existingKey = base64Encode(Uint8List(32));
        when(
          () => testContext.mockSecureStorage.read(key: StorageKeys.secureKey),
        ).thenAnswer((_) async => existingKey);

        final secureKey = await testContext.vaultStorage.getOrCreateSecureKey();

        expect(secureKey, isNotEmpty);
        expect(secureKey.length, equals(32));
        verifyNever(
          () => testContext.mockSecureStorage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          ),
        );
      });
    });

    group('Edge Cases - Data Types', () {
      test('should handle very large integers', () async {
        const largeInt = 9007199254740991; // Max safe integer
        when(
          () => testContext.mockNormalBox.put(any<String>(), any<String>()),
        ).thenAnswer((_) async {});
        when(() => testContext.mockNormalBox.containsKey('large')).thenReturn(true);
        when(() => testContext.mockNormalBox.get('large')).thenReturn('$largeInt');
        when(() => testContext.mockSecureBox.containsKey('large')).thenReturn(false);

        await testContext.vaultStorage.saveNormal(key: 'large', value: largeInt);
        final result = await testContext.vaultStorage.get<int>('large');

        expect(result, equals(largeInt));
      });

      test('should handle very long strings', () async {
        final longString = 'x' * 10000;
        when(
          () => testContext.mockNormalBox.put(any<String>(), any<String>()),
        ).thenAnswer((_) async {});
        when(() => testContext.mockNormalBox.containsKey('long')).thenReturn(true);
        when(() => testContext.mockNormalBox.get('long')).thenReturn('"$longString"');
        when(() => testContext.mockSecureBox.containsKey('long')).thenReturn(false);

        await testContext.vaultStorage.saveNormal(key: 'long', value: longString);
        final result = await testContext.vaultStorage.get<String>('long');

        expect(result, equals(longString));
      });

      test('should handle deeply nested maps', () async {
        final deepMap = {
          'level1': {
            'level2': {
              'level3': {
                'level4': {'value': 'deep'},
              },
            },
          },
        };

        when(
          () => testContext.mockNormalBox.put(any<String>(), any<Object?>()),
        ).thenAnswer((_) async {});
        when(() => testContext.mockNormalBox.containsKey('deep')).thenReturn(true);
        when(() => testContext.mockNormalBox.get('deep')).thenReturn({
          '__VST_STRATEGY__': 0, // StorageStrategy.native.index
          '__VST_VALUE__': deepMap,
        });
        when(() => testContext.mockSecureBox.containsKey('deep')).thenReturn(false);

        await testContext.vaultStorage.saveNormal(key: 'deep', value: deepMap);
        final result = await testContext.vaultStorage.get<Map<String, dynamic>>('deep');

        expect(result, equals(deepMap));
      });

      test('should handle lists with mixed types', () async {
        final mixedList = [1, 'two', 3.0, true, null];
        when(
          () => testContext.mockNormalBox.put(any<String>(), any<Object?>()),
        ).thenAnswer((_) async {});
        when(() => testContext.mockNormalBox.containsKey('mixed')).thenReturn(true);
        when(() => testContext.mockNormalBox.get('mixed')).thenReturn({
          '__VST_STRATEGY__': 0, // StorageStrategy.native.index
          '__VST_VALUE__': mixedList,
        });
        when(() => testContext.mockSecureBox.containsKey('mixed')).thenReturn(false);

        await testContext.vaultStorage.saveNormal(key: 'mixed', value: mixedList);
        final result = await testContext.vaultStorage.get<List<Object?>>('mixed');

        expect(result, equals(mixedList));
      });

      test('should handle empty string', () async {
        when(
          () => testContext.mockNormalBox.put(any<String>(), any<String>()),
        ).thenAnswer((_) async {});
        when(() => testContext.mockNormalBox.containsKey('empty')).thenReturn(true);
        when(() => testContext.mockNormalBox.get('empty')).thenReturn('""');
        when(() => testContext.mockSecureBox.containsKey('empty')).thenReturn(false);

        await testContext.vaultStorage.saveNormal(key: 'empty', value: '');
        final result = await testContext.vaultStorage.get<String>('empty');

        expect(result, equals(''));
      });

      test('should handle zero', () async {
        when(
          () => testContext.mockNormalBox.put(any<String>(), any<String>()),
        ).thenAnswer((_) async {});
        when(() => testContext.mockNormalBox.containsKey('zero')).thenReturn(true);
        when(() => testContext.mockNormalBox.get('zero')).thenReturn('0');
        when(() => testContext.mockSecureBox.containsKey('zero')).thenReturn(false);

        await testContext.vaultStorage.saveNormal(key: 'zero', value: 0);
        final result = await testContext.vaultStorage.get<int>('zero');

        expect(result, equals(0));
      });

      test('should handle negative numbers', () async {
        when(
          () => testContext.mockNormalBox.put(any<String>(), any<String>()),
        ).thenAnswer((_) async {});
        when(() => testContext.mockNormalBox.containsKey('negative')).thenReturn(true);
        when(() => testContext.mockNormalBox.get('negative')).thenReturn('-12345');
        when(() => testContext.mockSecureBox.containsKey('negative')).thenReturn(false);

        await testContext.vaultStorage.saveNormal(key: 'negative', value: -12345);
        final result = await testContext.vaultStorage.get<int>('negative');

        expect(result, equals(-12345));
      });

      test('should handle boolean values', () async {
        when(
          () => testContext.mockNormalBox.put(any<String>(), any<String>()),
        ).thenAnswer((_) async {});
        when(() => testContext.mockNormalBox.containsKey('bool_true')).thenReturn(true);
        when(() => testContext.mockNormalBox.containsKey('bool_false')).thenReturn(true);
        when(() => testContext.mockNormalBox.get('bool_true')).thenReturn('true');
        when(() => testContext.mockNormalBox.get('bool_false')).thenReturn('false');
        when(() => testContext.mockSecureBox.containsKey('bool_true')).thenReturn(false);
        when(() => testContext.mockSecureBox.containsKey('bool_false')).thenReturn(false);

        await testContext.vaultStorage.saveNormal(key: 'bool_true', value: true);
        await testContext.vaultStorage.saveNormal(key: 'bool_false', value: false);

        final resultTrue = await testContext.vaultStorage.get<bool>('bool_true');
        final resultFalse = await testContext.vaultStorage.get<bool>('bool_false');

        expect(resultTrue, isTrue);
        expect(resultFalse, isFalse);
      });

      test('should handle floating point numbers', () async {
        when(
          () => testContext.mockNormalBox.put(any<String>(), any<String>()),
        ).thenAnswer((_) async {});
        when(() => testContext.mockNormalBox.containsKey('float')).thenReturn(true);
        when(() => testContext.mockNormalBox.get('float')).thenReturn('3.14159');
        when(() => testContext.mockSecureBox.containsKey('float')).thenReturn(false);

        await testContext.vaultStorage.saveNormal(key: 'float', value: 3.14159);
        final result = await testContext.vaultStorage.get<double>('float');

        expect(result, equals(3.14159));
      });
    });
  });
}
