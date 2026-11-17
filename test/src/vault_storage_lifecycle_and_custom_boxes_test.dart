import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vault_storage/src/errors/errors.dart';
import 'package:vault_storage/src/storage/storage_strategy.dart';

import '../mocks.dart';
import '../test_context.dart';

Future<void> _expectSerializationErrorForBrokenMetadata(
  TestContext testContext, {
  required bool isSecure,
}) async {
  final files = isSecure ? testContext.mockSecureFilesBox : testContext.mockNormalFilesBox;
  final other = isSecure ? testContext.mockNormalFilesBox : testContext.mockSecureFilesBox;
  when(() => files.containsKey('broken')).thenReturn(true);
  when(() => files.get('broken')).thenAnswer((_) async => 'not json');
  when(() => other.containsKey('broken')).thenReturn(false);

  await expectLater(
    testContext.vaultStorage.getFile('broken'),
    throwsA(isA<VaultStorageSerializationError>()),
  );
}

void main() {
  group('init() re-entrancy', () {
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

    test('should return immediately when already initialized', () async {
      testContext.vaultStorage.isVaultStorageReady = true;

      // Should return without error
      await testContext.vaultStorage.init();

      // No interactions with secure storage (init body not executed)
      verifyNever(() => testContext.mockSecureStorage.read(key: any(named: 'key')));
    });
  });

  group('keys() includes custom box keys', () {
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

    test('should include keys from custom boxes', () async {
      final mockCustomBox = MockBox<Object?>();
      testContext.vaultStorage.customBoxes['tenant'] = mockCustomBox;

      when(() => testContext.mockNormalBox.keys).thenReturn(['normal_key']);
      when(() => testContext.mockSecureBox.keys).thenReturn(['secure_key']);
      when(() => testContext.mockNormalFilesBox.keys).thenReturn([]);
      when(() => testContext.mockSecureFilesBox.keys).thenReturn([]);
      when(() => mockCustomBox.keys).thenReturn(['custom_key']);

      final keys = await testContext.vaultStorage.keys();

      expect(keys, containsAll(['normal_key', 'secure_key', 'custom_key']));
    });

    test('should include custom box keys when isSecure is specified', () async {
      final mockCustomBox = MockBox<Object?>();
      testContext.vaultStorage.customBoxes['tenant'] = mockCustomBox;

      when(() => testContext.mockSecureBox.keys).thenReturn(['secure_key']);
      when(() => testContext.mockSecureFilesBox.keys).thenReturn([]);
      when(() => mockCustomBox.keys).thenReturn(['custom_key']);

      final keys = await testContext.vaultStorage.keys(isSecure: true);

      expect(keys, containsAll(['secure_key', 'custom_key']));
    });
  });

  group('clearNormal/clearSecure rethrow VaultStorageError', () {
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

    test('clearNormal should rethrow VaultStorageError without wrapping', () async {
      when(
        () => testContext.mockNormalBox.clear(),
      ).thenThrow(const VaultStorageDeleteError('inner error'));

      expect(
        () => testContext.vaultStorage.clearNormal(),
        throwsA(
          isA<VaultStorageDeleteError>().having((e) => e.message, 'message', equals('inner error')),
        ),
      );
    });

    test('clearSecure should rethrow VaultStorageError without wrapping', () async {
      when(
        () => testContext.mockSecureBox.clear(),
      ).thenThrow(const VaultStorageDeleteError('inner error'));

      expect(
        () => testContext.vaultStorage.clearSecure(),
        throwsA(
          isA<VaultStorageDeleteError>().having((e) => e.message, 'message', equals('inner error')),
        ),
      );
    });

    test('clearNormal should wrap non-VaultStorageError in VaultStorageDeleteError', () async {
      when(() => testContext.mockNormalBox.clear()).thenThrow(Exception('unexpected'));

      expect(
        () => testContext.vaultStorage.clearNormal(),
        throwsA(
          isA<VaultStorageDeleteError>().having(
            (e) => e.message,
            'message',
            equals('Failed to clear normal storage'),
          ),
        ),
      );
    });
  });

  group('dispose handles in-flight init', () {
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

    test('should dispose cleanly when not initialized and no pending init', () async {
      testContext.vaultStorage.isVaultStorageReady = false;

      // Should not throw
      await testContext.vaultStorage.dispose();

      expect(testContext.vaultStorage.isVaultStorageReady, isFalse);
    });

    test('should survive custom box close error during dispose', () async {
      final mockCustomBox = MockBox<Object?>();
      testContext.vaultStorage.customBoxes['failing'] = mockCustomBox;

      when(() => testContext.mockSecureBox.close()).thenAnswer((_) async {});
      when(() => testContext.mockNormalBox.close()).thenAnswer((_) async {});
      when(() => testContext.mockSecureFilesBox.close()).thenAnswer((_) async {});
      when(() => testContext.mockNormalFilesBox.close()).thenAnswer((_) async {});
      when(() => mockCustomBox.close()).thenThrow(Exception('close failed'));

      // Should not throw despite custom box close failure
      await testContext.vaultStorage.dispose();

      expect(testContext.vaultStorage.isVaultStorageReady, isFalse);
      expect(testContext.vaultStorage.customBoxes, isEmpty);
    });
  });

  group('Custom box file operations', () {
    late TestContext testContext;
    late MockBox<Object?> mockCustomBox;

    setUpAll(() {
      MocksHelper.registerFallbackValues();
    });

    setUp(() {
      testContext = TestContext();
      testContext.setUpCommon();
      mockCustomBox = MockBox<Object?>();
      testContext.vaultStorage.customBoxes['tenant'] = mockCustomBox;
    });

    tearDown(() {
      testContext.tearDownCommon();
    });

    test('saveSecureFile to custom box should store base64 data', () async {
      when(() => mockCustomBox.containsKey(any<Object?>())).thenReturn(false);
      when(() => mockCustomBox.put(any<Object?>(), any<Object?>())).thenAnswer((_) async {});

      await testContext.vaultStorage.saveSecureFile(
        key: 'myfile',
        fileBytes: .fromList([1, 2, 3]),
        originalFileName: 'test.png',
        metadata: {'author': 'tester'},
        box: 'tenant',
      );

      final captured = verify(
        () => mockCustomBox.put('myfile', captureAny<Object?>()),
      ).captured.single;
      // _putInBoxBase now stores StoredValue directly (v4.x TypeAdapter format)
      expect(captured, isA<StoredValue>());
    });

    test('saveSecureFile to non-existent box should throw BoxNotFoundError', () {
      expect(
        () => testContext.vaultStorage.saveSecureFile(
          key: 'myfile',
          fileBytes: .fromList([1, 2, 3]),
          box: 'unknown_box',
        ),
        throwsA(isA<BoxNotFoundError>()),
      );
    });

    test('saveNormalFile to custom box should store base64 data', () async {
      when(() => mockCustomBox.containsKey(any<Object?>())).thenReturn(false);
      when(() => mockCustomBox.put(any<Object?>(), any<Object?>())).thenAnswer((_) async {});

      await testContext.vaultStorage.saveNormalFile(
        key: 'myfile',
        fileBytes: .fromList([4, 5, 6]),
        originalFileName: 'data.bin',
        metadata: {'category': 'docs'},
        box: 'tenant',
      );

      final captured = verify(
        () => mockCustomBox.put('myfile', captureAny<Object?>()),
      ).captured.single;
      // _putInBoxBase now stores StoredValue directly (v4.x TypeAdapter format)
      expect(captured, isA<StoredValue>());
    });

    test('saveNormalFile to non-existent box should throw BoxNotFoundError', () {
      expect(
        () => testContext.vaultStorage.saveNormalFile(
          key: 'myfile',
          fileBytes: .fromList([1, 2, 3]),
          box: 'unknown_box',
        ),
        throwsA(isA<BoxNotFoundError>()),
      );
    });

    test('getFile from custom box should return decoded bytes', () async {
      when(() => mockCustomBox.containsKey('myfile')).thenReturn(true);
      // For Box<Object?>, _getFromBoxBase calls box.get(key) synchronously.
      when(
        () => mockCustomBox.get('myfile'),
      ).thenReturn('{"base64Data":"AQID","extension":"bin","isCustomBox":true}');

      final result = await testContext.vaultStorage.getFile('myfile', box: 'tenant');

      expect(result, isNotNull);
      expect(result, equals(Uint8List.fromList([1, 2, 3])));
    });

    test('getFile from non-existent custom box should throw BoxNotFoundError', () {
      expect(
        () => testContext.vaultStorage.getFile('myfile', box: 'unknown_box'),
        throwsA(isA<BoxNotFoundError>()),
      );
    });

    test('getFile from custom box returns null when key not found', () async {
      when(() => mockCustomBox.containsKey('missing')).thenReturn(false);

      final result = await testContext.vaultStorage.getFile('missing', box: 'tenant');

      expect(result, isNull);
    });

    test('getFile from custom box throws VaultStorageReadError for invalid metadata', () async {
      when(() => mockCustomBox.containsKey('bad')).thenReturn(true);
      // Return data without 'isCustomBox: true' (plain JSON string, legacy format)
      when(() => mockCustomBox.get('bad')).thenReturn('{"someField":"data"}');

      expect(
        () => testContext.vaultStorage.getFile('bad', box: 'tenant'),
        throwsA(
          isA<VaultStorageReadError>().having(
            (e) => e.message,
            'message',
            contains('Invalid custom box file metadata'),
          ),
        ),
      );
    });
  });

  group('getFile auto-search', () {
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

    test('should return null when key not found in any box', () async {
      when(() => testContext.mockNormalFilesBox.containsKey('missing')).thenReturn(false);
      when(() => testContext.mockSecureFilesBox.containsKey('missing')).thenReturn(false);

      final result = await testContext.vaultStorage.getFile('missing');

      expect(result, isNull);
    });

    test('throws VaultStorageSerializationError for broken normal file metadata', () {
      return _expectSerializationErrorForBrokenMetadata(testContext, isSecure: false);
    });

    test('throws VaultStorageSerializationError for broken secure file metadata', () {
      return _expectSerializationErrorForBrokenMetadata(testContext, isSecure: true);
    });

    test('should throw AmbiguousKeyError when file in multiple default boxes', () async {
      // Normal files box has the key
      when(() => testContext.mockNormalFilesBox.containsKey('ambiguous')).thenReturn(true);
      when(
        () => testContext.mockNormalFilesBox.get('ambiguous'),
      ).thenAnswer((_) async => '{"fileId":"1","filePath":"/f","isSecure":false}');

      // Secure files box also has the key
      when(() => testContext.mockSecureFilesBox.containsKey('ambiguous')).thenReturn(true);
      when(
        () => testContext.mockSecureFilesBox.get('ambiguous'),
      ).thenAnswer((_) async => '{"fileId":"2","filePath":"/g","isSecure":true}');

      expect(
        () => testContext.vaultStorage.getFile('ambiguous'),
        throwsA(isA<AmbiguousKeyError>()),
      );
    });
  });

  group('Type coercion', () {
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

    test('should throw VaultStorageReadError for incompatible type', () async {
      // Store a bool value directly in normal box
      when(() => testContext.mockNormalBox.containsKey('typed')).thenReturn(true);
      when(() => testContext.mockNormalBox.get('typed')).thenReturn(true);

      expect(
        () => testContext.vaultStorage.get<List<int>>('typed', isSecure: false),
        throwsA(
          isA<VaultStorageReadError>().having(
            (e) => e.message,
            'message',
            contains('Type mismatch'),
          ),
        ),
      );
    });

    test('should coerce int from num', () async {
      when(() => testContext.mockNormalBox.containsKey('num_val')).thenReturn(true);
      when(() => testContext.mockNormalBox.get('num_val')).thenReturn(42.0);

      final result = await testContext.vaultStorage.get<int>('num_val', isSecure: false);

      expect(result, equals(42));
    });

    test('should coerce double from int', () async {
      when(() => testContext.mockNormalBox.containsKey('int_val')).thenReturn(true);
      when(() => testContext.mockNormalBox.get('int_val')).thenReturn(42);

      final result = await testContext.vaultStorage.get<double>('int_val', isSecure: false);

      expect(result, equals(42.0));
    });
  });

  group('AmbiguousKeyError', () {
    test('should store key and foundInBoxes', () {
      final boxes = ['box1', 'box2'];
      final error = AmbiguousKeyError('test_key', boxes, 'Key found in multiple boxes');

      expect(error.key, equals('test_key'));
      expect(error.foundInBoxes, equals(['box1', 'box2']));
      expect(error.message, equals('Key found in multiple boxes'));
      expect(error.originalException, isNull);
    });

    test('should format toString correctly', () {
      final boxes = ['normal', 'secure'];
      final error = AmbiguousKeyError('key', boxes, 'Ambiguous key');

      expect(error.toString(), equals('AmbiguousKeyError: Ambiguous key'));
    });
  });
}
