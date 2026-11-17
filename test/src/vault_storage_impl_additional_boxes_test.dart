import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

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

    group('Custom Box Operations', () {
      late MockBox<Object?> mockCustomBox;

      setUp(() {
        mockCustomBox = MockBox<Object?>();
        testContext.vaultStorage.customBoxes['testBox'] = mockCustomBox;
      });

      test('should save to custom box successfully', () async {
        when(() => mockCustomBox.put(any<String>(), any<Object?>())).thenAnswer((_) async {});
        when(() => mockCustomBox.containsKey('custom_key')).thenReturn(true);
        when(() => mockCustomBox.get('custom_key')).thenReturn('"custom_value"');

        await testContext.vaultStorage.saveNormal(
          key: 'custom_key',
          value: 'custom_value',
          box: 'testBox',
        );

        verify(() => mockCustomBox.put(any<String>(), any<Object?>())).called(1);
      });

      test('should get from custom box successfully', () async {
        when(() => mockCustomBox.containsKey('custom_key')).thenReturn(true);
        when(() => mockCustomBox.get('custom_key')).thenReturn('"custom_value"');

        final result = await testContext.vaultStorage.get<String>('custom_key', box: 'testBox');

        expect(result, equals('custom_value'));
        verify(() => mockCustomBox.get('custom_key')).called(1);
      });

      test('should delete from custom box successfully', () async {
        when(() => mockCustomBox.containsKey('custom_key')).thenReturn(true);
        when(() => mockCustomBox.delete('custom_key')).thenAnswer((_) async {});

        await testContext.vaultStorage.delete('custom_key', box: 'testBox');

        verify(() => mockCustomBox.delete('custom_key')).called(1);
      });

      test('should handle non-existent key in custom box', () async {
        when(() => mockCustomBox.containsKey('nonexistent')).thenReturn(false);

        final result = await testContext.vaultStorage.get<String>('nonexistent', box: 'testBox');

        expect(result, isNull);
      });

      test('should save secure to custom box', () async {
        when(() => mockCustomBox.put(any<String>(), any<Object?>())).thenAnswer((_) async {});

        await testContext.vaultStorage.saveSecure(
          key: 'secure_key',
          value: 'secure_value',
          box: 'testBox',
        );

        verify(() => mockCustomBox.put(any<String>(), any<Object?>())).called(1);
      });

      test('should save file to custom box successfully', () async {
        when(() => mockCustomBox.put(any<String>(), any<Object?>())).thenAnswer((_) async {});

        final fileBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
        await testContext.vaultStorage.saveNormalFile(
          key: 'file_key',
          fileBytes: fileBytes,
          originalFileName: 'test.txt',
          box: 'testBox',
        );

        verify(() => mockCustomBox.put('file_key', any<Object?>())).called(1);
      });

      test('should get file from custom box successfully', () async {
        final base64Data = base64Encode(Uint8List.fromList([1, 2, 3, 4, 5]));
        final metadata = {'base64Data': base64Data, 'extension': 'txt', 'isCustomBox': true};

        when(() => mockCustomBox.containsKey('file_key')).thenReturn(true);
        when(() => mockCustomBox.get('file_key')).thenReturn(jsonEncode(metadata));

        final result = await testContext.vaultStorage.getFile('file_key', box: 'testBox');

        expect(result, isNotNull);
        expect(result, equals(Uint8List.fromList([1, 2, 3, 4, 5])));
      });

      test('should delete file from custom box successfully', () async {
        when(() => mockCustomBox.containsKey('file_key')).thenReturn(true);
        when(() => mockCustomBox.delete('file_key')).thenAnswer((_) async {});

        await testContext.vaultStorage.deleteFile('file_key', box: 'testBox');

        verify(() => mockCustomBox.delete('file_key')).called(1);
      });

      test('should handle delete from custom box when key does not exist', () async {
        when(() => mockCustomBox.containsKey('missing')).thenReturn(false);

        await testContext.vaultStorage.delete('missing', box: 'testBox');

        verifyNever(() => mockCustomBox.delete(any<String>()));
      });
    });

    group('Ambiguous Key Detection', () {
      late MockBox<String> mockCustomBox1;
      late MockBox<String> mockCustomBox2;

      setUp(() {
        mockCustomBox1 = MockBox<String>();
        mockCustomBox2 = MockBox<String>();
        testContext.vaultStorage.customBoxes['box1'] = mockCustomBox1;
        testContext.vaultStorage.customBoxes['box2'] = mockCustomBox2;
      });

      test('should not throw AmbiguousKeyError when key exists in only one box', () async {
        const key = 'unique_key';

        when(() => mockCustomBox1.containsKey(key)).thenReturn(true);
        when(() => mockCustomBox1.get(key)).thenReturn('"value1"');
        when(() => mockCustomBox2.containsKey(key)).thenReturn(false);

        when(() => testContext.mockNormalBox.containsKey(key)).thenReturn(false);
        when(() => testContext.mockSecureBox.containsKey(key)).thenReturn(false);

        final result = await testContext.vaultStorage.get<String>(key);
        expect(result, equals('value1'));
      });
    });

    group('Dispose Operations', () {
      late MockBox<String> mockCustomBox;

      setUp(() {
        mockCustomBox = MockBox<String>();
        testContext.vaultStorage.customBoxes['testBox'] = mockCustomBox;
      });

      test('should close custom boxes on dispose', () async {
        testContext.vaultStorage.isVaultStorageReady = true;

        when(() => testContext.mockNormalBox.close()).thenAnswer((_) async {});
        when(() => testContext.mockSecureBox.close()).thenAnswer((_) async {});
        when(() => testContext.mockNormalFilesBox.close()).thenAnswer((_) async {});
        when(() => testContext.mockSecureFilesBox.close()).thenAnswer((_) async {});
        when(() => mockCustomBox.close()).thenAnswer((_) async {});

        await testContext.vaultStorage.dispose();

        expect(testContext.vaultStorage.customBoxes, isEmpty);
        verify(() => mockCustomBox.close()).called(1);
      });

      test('should handle errors when closing custom boxes', () async {
        testContext.vaultStorage.isVaultStorageReady = true;

        when(() => testContext.mockNormalBox.close()).thenAnswer((_) async {});
        when(() => testContext.mockSecureBox.close()).thenAnswer((_) async {});
        when(() => testContext.mockNormalFilesBox.close()).thenAnswer((_) async {});
        when(() => testContext.mockSecureFilesBox.close()).thenAnswer((_) async {});
        when(() => mockCustomBox.close()).thenThrow(Exception('Close error'));

        await testContext.vaultStorage.dispose();

        expect(testContext.vaultStorage.isVaultStorageReady, isFalse);
      });
    });

    group('Delete from Multiple Boxes', () {
      late MockBox<String> mockCustomBox;

      setUp(() {
        mockCustomBox = MockBox<String>();
        testContext.vaultStorage.customBoxes['testBox'] = mockCustomBox;
      });

      test('should delete from all boxes including custom when no box specified', () async {
        const key = 'everywhere';

        when(() => testContext.mockNormalBox.containsKey(key)).thenReturn(true);
        when(() => testContext.mockSecureBox.containsKey(key)).thenReturn(true);
        when(() => mockCustomBox.containsKey(key)).thenReturn(true);
        when(() => testContext.mockNormalBox.delete(key)).thenAnswer((_) async {});
        when(() => testContext.mockSecureBox.delete(key)).thenAnswer((_) async {});
        when(() => mockCustomBox.delete(key)).thenAnswer((_) async {});

        await testContext.vaultStorage.delete(key);

        verify(() => testContext.mockNormalBox.delete(key)).called(1);
        verify(() => testContext.mockSecureBox.delete(key)).called(1);
        verify(() => mockCustomBox.delete(key)).called(1);
      });
    });

    group('Security Validation', () {
      test('should allow saveNormal even in insecure environment', () async {
        testContext.vaultStorage.isSecureEnvironment = false;

        when(
          () => testContext.mockNormalBox.put(any<String>(), any<String>()),
        ).thenAnswer((_) async {});

        await testContext.vaultStorage.saveNormal(key: 'test', value: 'value');

        verify(() => testContext.mockNormalBox.put(any<String>(), any<String>())).called(1);
      });
    });
  });
}
