import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vault_storage/src/constants/vault_storage_config.dart';
import 'package:vault_storage/src/errors/errors.dart';
import 'package:vault_storage/src/storage/storage_strategy.dart';

import '../mocks.dart';
import '../test_context.dart';

void main() {
  group('get() auto-search ambiguity detection', () {
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

    test('should throw AmbiguousKeyError when key found in both default boxes', () async {
      // Key exists in both normal AND secure boxes (stored as native StoredValue)
      final normalWrapped = const StoredValue('normal_val', .native).toHiveMap();
      final secureWrapped = const StoredValue('secure_val', .native).toHiveMap();
      when(() => testContext.mockNormalBox.containsKey('shared')).thenReturn(true);
      when(() => testContext.mockNormalBox.get('shared')).thenReturn(normalWrapped);
      when(() => testContext.mockSecureBox.containsKey('shared')).thenReturn(true);
      when(() => testContext.mockSecureBox.get('shared')).thenReturn(secureWrapped);

      expect(
        () => testContext.vaultStorage.get<String>('shared'),
        throwsA(
          isA<AmbiguousKeyError>().having(
            (e) => e.foundInBoxes,
            'foundInBoxes',
            containsAll(['normal', 'secure']),
          ),
        ),
      );
    });

    test('lists ambiguous boxes in opening order and reads a lone custom hit', () async {
      final firstBox = MockBox<Object?>();
      final secondBox = MockBox<Object?>();
      testContext.vaultStorage.customBoxes['box_a'] = firstBox;
      testContext.vaultStorage.customBoxes['box_b'] = secondBox;
      final wrapped = const StoredValue('custom_val', .native).toHiveMap();
      when(() => testContext.mockNormalBox.containsKey('shared')).thenReturn(false);
      when(() => testContext.mockSecureBox.containsKey('shared')).thenReturn(false);
      when(() => firstBox.containsKey('shared')).thenReturn(false);
      when(() => secondBox.containsKey('shared')).thenReturn(true);
      when(() => secondBox.get('shared')).thenReturn(wrapped);

      expect(await testContext.vaultStorage.get<String>('shared'), 'custom_val');

      when(() => firstBox.containsKey('shared')).thenReturn(true);
      when(() => firstBox.get('shared')).thenReturn(wrapped);
      expect(
        () => testContext.vaultStorage.get<String>('shared'),
        throwsA(
          isA<AmbiguousKeyError>().having((e) => e.foundInBoxes, 'foundInBoxes', [
            'box_a',
            'box_b',
          ]),
        ),
      );
    });

    test('should throw AmbiguousKeyError when key in default box and custom box', () async {
      final mockCustomBox = MockBox<Object?>();
      testContext.vaultStorage.customBoxes['tenant'] = mockCustomBox;

      final normalWrapped = const StoredValue('normal_val', .native).toHiveMap();
      final customWrapped = const StoredValue('custom_val', .native).toHiveMap();
      when(() => testContext.mockNormalBox.containsKey('shared')).thenReturn(true);
      when(() => testContext.mockNormalBox.get('shared')).thenReturn(normalWrapped);
      when(() => testContext.mockSecureBox.containsKey('shared')).thenReturn(false);
      when(() => mockCustomBox.containsKey('shared')).thenReturn(true);
      when(() => mockCustomBox.get('shared')).thenReturn(customWrapped);

      expect(
        () => testContext.vaultStorage.get<String>('shared'),
        throwsA(
          isA<AmbiguousKeyError>().having(
            (e) => e.foundInBoxes,
            'foundInBoxes',
            containsAll(['normal', 'tenant']),
          ),
        ),
      );
    });
  });

  group('saveSecureFile streaming and metadata', () {
    late TestContext testContext;
    late int originalThreshold;

    setUpAll(() {
      MocksHelper.registerFallbackValues();
    });

    setUp(() {
      testContext = TestContext();
      testContext.setUpCommon();
      originalThreshold = VaultStorageConfig.secureFileStreamingThresholdBytes;
    });

    tearDown(() {
      VaultStorageConfig.secureFileStreamingThresholdBytes = originalThreshold;
      testContext.tearDownCommon();
    });

    test('should use streaming path when file exceeds threshold', () async {
      // Lower threshold to trigger streaming path
      VaultStorageConfig.secureFileStreamingThresholdBytes = 1;

      final streamMetadata = {'fileId': 'stream-id', 'extension': 'bin'};
      when(
        () => testContext.mockFileOperations.saveSecureFileStream(any()),
      ).thenAnswer((_) async => streamMetadata);
      when(
        () => testContext.mockSecureFilesBox.put(any<Object?>(), any<Object?>()),
      ).thenAnswer((_) async {});

      await testContext.vaultStorage.saveSecureFile(
        key: 'big_file',
        fileBytes: .fromList([1, 2, 3]),
      );

      verify(() => testContext.mockFileOperations.saveSecureFileStream(any())).called(1);
    });

    test('should include user metadata in secure file storage', () async {
      final mockMetadata = {'fileId': 'test-id', 'extension': 'txt'};
      when(
        () => testContext.mockFileOperations.saveSecureFile(any()),
      ).thenAnswer((_) async => mockMetadata);
      when(
        () => testContext.mockSecureFilesBox.put(any<Object?>(), any<Object?>()),
      ).thenAnswer((_) async {});

      await testContext.vaultStorage.saveSecureFile(
        key: 'with_meta',
        fileBytes: .fromList([1, 2]),
        metadata: {'author': 'test'},
      );

      final captured = verify(
        () => testContext.mockSecureFilesBox.put('with_meta', captureAny<Object?>()),
      ).captured.single;
      expect(
        captured,
        isA<StoredValue>().having(
          (stored) => stored.value,
          'value',
          isA<Map<Object?, Object?>>().having(
            (map) => map['userMetadata'],
            'userMetadata',
            equals({'author': 'test'}),
          ),
        ),
      );
    });
  });

  group('saveNormalFile with metadata', () {
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

    test('should include user metadata in normal file storage', () async {
      final mockMetadata = {'fileId': 'normal-id', 'extension': 'pdf'};
      when(
        () => testContext.mockFileOperations.saveNormalFile(any()),
      ).thenAnswer((_) async => mockMetadata);
      when(
        () => testContext.mockNormalFilesBox.put(any<Object?>(), any<Object?>()),
      ).thenAnswer((_) async {});

      await testContext.vaultStorage.saveNormalFile(
        key: 'doc',
        fileBytes: .fromList([10, 20]),
        metadata: {'category': 'reports'},
      );

      final captured = verify(
        () => testContext.mockNormalFilesBox.put('doc', captureAny<Object?>()),
      ).captured.single;
      expect(
        captured,
        isA<StoredValue>().having(
          (stored) => stored.value,
          'value',
          isA<Map<Object?, Object?>>().having(
            (map) => map['userMetadata'],
            'userMetadata',
            equals({'category': 'reports'}),
          ),
        ),
      );
    });
  });

  group('getFile content retrieval paths', () {
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

    test('getFile with isSecure=false returns normal file via getNormalFile', () async {
      final expectedBytes = Uint8List.fromList([10, 20, 30]);
      const jsonMetadata = '{"fileId":"n-id","isSecure":false}';

      when(() => testContext.mockNormalFilesBox.containsKey('myfile')).thenReturn(true);
      when(
        () => testContext.mockNormalFilesBox.get('myfile'),
      ).thenAnswer((_) async => jsonMetadata);
      when(
        () => testContext.mockFileOperations.getNormalFile(
          fileMetadata: any(named: 'fileMetadata'),
          isWeb: any(named: 'isWeb'),
          getBox: any(named: 'getBox'),
        ),
      ).thenAnswer((_) async => expectedBytes);

      final result = await testContext.vaultStorage.getFile('myfile', isSecure: false);

      expect(result, equals(expectedBytes));
      verify(
        () => testContext.mockFileOperations.getNormalFile(
          fileMetadata: any(named: 'fileMetadata'),
          isWeb: any(named: 'isWeb'),
          getBox: any(named: 'getBox'),
        ),
      ).called(1);
    });

    test('getFile auto-search finds file in normal box and returns content', () async {
      final expectedBytes = Uint8List.fromList([5, 6, 7]);
      const jsonMetadata = '{"fileId":"auto-n","filePath":"/f"}';

      // File only in normal files box
      when(() => testContext.mockNormalFilesBox.containsKey('autofile')).thenReturn(true);
      when(
        () => testContext.mockNormalFilesBox.get('autofile'),
      ).thenAnswer((_) async => jsonMetadata);
      when(() => testContext.mockSecureFilesBox.containsKey('autofile')).thenReturn(false);

      when(
        () => testContext.mockFileOperations.getNormalFile(
          fileMetadata: any(named: 'fileMetadata'),
          isWeb: any(named: 'isWeb'),
          getBox: any(named: 'getBox'),
        ),
      ).thenAnswer((_) async => expectedBytes);

      final result = await testContext.vaultStorage.getFile('autofile');

      expect(result, equals(expectedBytes));
      verify(
        () => testContext.mockFileOperations.getNormalFile(
          fileMetadata: any(named: 'fileMetadata'),
          isWeb: any(named: 'isWeb'),
          getBox: any(named: 'getBox'),
        ),
      ).called(1);
    });

    test('getFile auto-search finds file in secure box and returns content', () async {
      final expectedBytes = Uint8List.fromList([8, 9, 10]);
      const jsonMetadata = '{"fileId":"auto-s","filePath":"/g"}';

      // File only in secure files box
      when(() => testContext.mockNormalFilesBox.containsKey('secfile')).thenReturn(false);
      when(() => testContext.mockSecureFilesBox.containsKey('secfile')).thenReturn(true);
      when(
        () => testContext.mockSecureFilesBox.get('secfile'),
      ).thenAnswer((_) async => jsonMetadata);

      when(
        () => testContext.mockFileOperations.getSecureFile(
          fileMetadata: any(named: 'fileMetadata'),
          isWeb: any(named: 'isWeb'),
          secureStorage: any(named: 'secureStorage'),
          getBox: any(named: 'getBox'),
        ),
      ).thenAnswer((_) async => expectedBytes);

      final result = await testContext.vaultStorage.getFile('secfile');

      expect(result, equals(expectedBytes));
      verify(
        () => testContext.mockFileOperations.getSecureFile(
          fileMetadata: any(named: 'fileMetadata'),
          isWeb: any(named: 'isWeb'),
          secureStorage: any(named: 'secureStorage'),
          getBox: any(named: 'getBox'),
        ),
      ).called(1);
    });

    test('getFile auto-search finds file in custom box and returns decoded bytes', () async {
      final mockCustomBox = MockBox<Object?>();
      testContext.vaultStorage.customBoxes['tenant'] = mockCustomBox;

      // No file in default boxes
      when(() => testContext.mockNormalFilesBox.containsKey('cbfile')).thenReturn(false);
      when(() => testContext.mockSecureFilesBox.containsKey('cbfile')).thenReturn(false);

      // File in custom box (stored as legacy JSON string with isCustomBox flag)
      when(() => mockCustomBox.containsKey('cbfile')).thenReturn(true);
      when(
        () => mockCustomBox.get('cbfile'),
      ).thenReturn('{"base64Data":"AQID","extension":"bin","isCustomBox":true}');

      final result = await testContext.vaultStorage.getFile('cbfile');

      expect(result, equals(Uint8List.fromList([1, 2, 3])));
    });
  });
}
