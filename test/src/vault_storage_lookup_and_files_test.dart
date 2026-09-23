import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vault_storage/src/constants/config.dart';
import 'package:vault_storage/src/enum/storage_box_type.dart';
import 'package:vault_storage/src/errors/errors.dart';
import 'package:vault_storage/src/storage/storage_strategy.dart';
import 'package:vault_storage/src/vault_storage_impl.dart';

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
      final normalWrapped = const StoredValue('normal_val', StorageStrategy.native).toHiveMap();
      final secureWrapped = const StoredValue('secure_val', StorageStrategy.native).toHiveMap();
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

    test('should throw AmbiguousKeyError when key in default box and custom box', () async {
      final mockCustomBox = MockBox<dynamic>();
      testContext.vaultStorage.customBoxes['tenant'] = mockCustomBox;

      final normalWrapped = const StoredValue('normal_val', StorageStrategy.native).toHiveMap();
      final customWrapped = const StoredValue('custom_val', StorageStrategy.native).toHiveMap();
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
        () => testContext.mockFileOperations.saveSecureFileStream(
          stream: any(named: 'stream'),
          fileExtension: any(named: 'fileExtension'),
          isWeb: any(named: 'isWeb'),
          secureStorage: any(named: 'secureStorage'),
          uuid: any(named: 'uuid'),
          getBox: any(named: 'getBox'),
          chunkSize: any(named: 'chunkSize'),
        ),
      ).thenAnswer((_) async => streamMetadata);
      when(
        () => testContext.mockSecureFilesBox.put(any<dynamic>(), any<dynamic>()),
      ).thenAnswer((_) async {});

      await testContext.vaultStorage.saveSecureFile(
        key: 'big_file',
        fileBytes: Uint8List.fromList([1, 2, 3]),
      );

      verify(
        () => testContext.mockFileOperations.saveSecureFileStream(
          stream: any(named: 'stream'),
          fileExtension: any(named: 'fileExtension'),
          isWeb: any(named: 'isWeb'),
          secureStorage: any(named: 'secureStorage'),
          uuid: any(named: 'uuid'),
          getBox: any(named: 'getBox'),
          chunkSize: any(named: 'chunkSize'),
        ),
      ).called(1);
    });

    test('should include user metadata in secure file storage', () async {
      final mockMetadata = {'fileId': 'test-id', 'extension': 'txt'};
      when(
        () => testContext.mockFileOperations.saveSecureFile(
          fileBytes: any(named: 'fileBytes'),
          fileExtension: any(named: 'fileExtension'),
          isWeb: any(named: 'isWeb'),
          secureStorage: any(named: 'secureStorage'),
          uuid: any(named: 'uuid'),
          getBox: any(named: 'getBox'),
        ),
      ).thenAnswer((_) async => mockMetadata);
      when(
        () => testContext.mockSecureFilesBox.put(any<dynamic>(), any<dynamic>()),
      ).thenAnswer((_) async {});

      await testContext.vaultStorage.saveSecureFile(
        key: 'with_meta',
        fileBytes: Uint8List.fromList([1, 2]),
        metadata: {'author': 'test'},
      );

      final captured =
          verify(
                () => testContext.mockSecureFilesBox.put('with_meta', captureAny<dynamic>()),
              ).captured.single
              as StoredValue;
      expect(captured.value, isA<Map<dynamic, dynamic>>());
      expect((captured.value as Map<dynamic, dynamic>)['userMetadata'], equals({'author': 'test'}));
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
        () => testContext.mockFileOperations.saveNormalFile(
          fileBytes: any(named: 'fileBytes'),
          fileExtension: any(named: 'fileExtension'),
          isWeb: any(named: 'isWeb'),
          uuid: any(named: 'uuid'),
          getBox: any(named: 'getBox'),
        ),
      ).thenAnswer((_) async => mockMetadata);
      when(
        () => testContext.mockNormalFilesBox.put(any<dynamic>(), any<dynamic>()),
      ).thenAnswer((_) async {});

      await testContext.vaultStorage.saveNormalFile(
        key: 'doc',
        fileBytes: Uint8List.fromList([10, 20]),
        metadata: {'category': 'reports'},
      );

      final captured =
          verify(
                () => testContext.mockNormalFilesBox.put('doc', captureAny<dynamic>()),
              ).captured.single
              as StoredValue;
      expect(captured.value, isA<Map<dynamic, dynamic>>());
      expect(
        (captured.value as Map<dynamic, dynamic>)['userMetadata'],
        equals({'category': 'reports'}),
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
      final mockCustomBox = MockBox<dynamic>();
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

  group('clearAllFilesInBox with entries', () {
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

    test('should delete underlying normal files before clearing box', () async {
      const jsonMetadata = '{"fileId":"f1","filePath":"/tmp/f1.txt"}';

      when(() => testContext.mockNormalFilesBox.keys).thenReturn(['file1']);
      when(() => testContext.mockNormalFilesBox.containsKey('file1')).thenReturn(true);
      when(() => testContext.mockNormalFilesBox.get('file1')).thenAnswer((_) async => jsonMetadata);
      when(() => testContext.mockNormalFilesBox.clear()).thenAnswer((_) async => 0);

      when(
        () => testContext.mockFileOperations.deleteNormalFile(
          fileMetadata: any(named: 'fileMetadata'),
          isWeb: any(named: 'isWeb'),
          getBox: any(named: 'getBox'),
        ),
      ).thenAnswer((_) async {});

      await testContext.vaultStorage.clearAllFilesInBox(BoxType.normalFiles, isSecure: false);

      verify(
        () => testContext.mockFileOperations.deleteNormalFile(
          fileMetadata: any(named: 'fileMetadata'),
          isWeb: any(named: 'isWeb'),
          getBox: any(named: 'getBox'),
        ),
      ).called(1);
      verify(() => testContext.mockNormalFilesBox.clear()).called(1);
    });

    test('should delete underlying secure files before clearing box', () async {
      const jsonMetadata = '{"fileId":"s1","filePath":"/tmp/s1.enc"}';

      when(() => testContext.mockSecureFilesBox.keys).thenReturn(['sfile1']);
      when(() => testContext.mockSecureFilesBox.containsKey('sfile1')).thenReturn(true);
      when(
        () => testContext.mockSecureFilesBox.get('sfile1'),
      ).thenAnswer((_) async => jsonMetadata);
      when(() => testContext.mockSecureFilesBox.clear()).thenAnswer((_) async => 0);

      when(
        () => testContext.mockFileOperations.deleteSecureFile(
          fileMetadata: any(named: 'fileMetadata'),
          isWeb: any(named: 'isWeb'),
          secureStorage: any(named: 'secureStorage'),
          getBox: any(named: 'getBox'),
        ),
      ).thenAnswer((_) async {});

      await testContext.vaultStorage.clearAllFilesInBox(BoxType.secureFiles, isSecure: true);

      verify(
        () => testContext.mockFileOperations.deleteSecureFile(
          fileMetadata: any(named: 'fileMetadata'),
          isWeb: any(named: 'isWeb'),
          secureStorage: any(named: 'secureStorage'),
          getBox: any(named: 'getBox'),
        ),
      ).called(1);
      verify(() => testContext.mockSecureFilesBox.clear()).called(1);
    });

    test('should continue on per-file delete errors', () async {
      const jsonMetadata = '{"fileId":"f1","filePath":"/tmp/f1.txt"}';

      when(() => testContext.mockNormalFilesBox.keys).thenReturn(['file1', 'file2']);
      when(() => testContext.mockNormalFilesBox.containsKey(any<dynamic>())).thenReturn(true);
      when(
        () => testContext.mockNormalFilesBox.get(any<dynamic>()),
      ).thenAnswer((_) async => jsonMetadata);
      when(() => testContext.mockNormalFilesBox.clear()).thenAnswer((_) async => 0);

      // First file delete throws, second succeeds
      var callCount = 0;
      when(
        () => testContext.mockFileOperations.deleteNormalFile(
          fileMetadata: any(named: 'fileMetadata'),
          isWeb: any(named: 'isWeb'),
          getBox: any(named: 'getBox'),
        ),
      ).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) throw Exception('IO error');
      });

      // Should not throw despite first file failing
      await testContext.vaultStorage.clearAllFilesInBox(BoxType.normalFiles, isSecure: false);

      verify(() => testContext.mockNormalFilesBox.clear()).called(1);
    });
  });

  group('keys() error handling', () {
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

    test('should wrap errors in StorageReadError', () async {
      when(() => testContext.mockNormalBox.keys).thenThrow(Exception('corrupted'));

      expect(
        () => testContext.vaultStorage.keys(),
        throwsA(
          isA<StorageReadError>().having(
            (e) => e.message,
            'message',
            equals('Failed to list keys'),
          ),
        ),
      );
    });
  });

  group('deleteFile with file metadata', () {
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

    test('should delete from custom boxes during default deleteFile', () async {
      final mockCustomBox = MockBox<dynamic>();
      testContext.vaultStorage.customBoxes['tenant'] = mockCustomBox;

      // No metadata in default file boxes
      when(() => testContext.mockNormalFilesBox.containsKey('cf')).thenReturn(false);
      when(() => testContext.mockSecureFilesBox.containsKey('cf')).thenReturn(false);

      // Key exists in custom box
      when(() => mockCustomBox.containsKey('cf')).thenReturn(true);
      when(() => mockCustomBox.delete('cf')).thenAnswer((_) async {});

      await testContext.vaultStorage.deleteFile('cf');

      verify(() => mockCustomBox.delete('cf')).called(1);
    });
  });

  group('_getFromBoxBase JSON strategy path', () {
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

    test('should decode JSON-strategy wrapped values', () async {
      // Create a StoredValue map with JSON strategy containing a JSON-encoded map
      final wrappedValue = const StoredValue(
        '{"name":"test","count":42}',
        StorageStrategy.json,
      ).toHiveMap();

      when(() => testContext.mockNormalBox.containsKey('json_val')).thenReturn(true);
      when(() => testContext.mockNormalBox.get('json_val')).thenReturn(wrappedValue);

      final result = await testContext.vaultStorage.get<Map<String, dynamic>>(
        'json_val',
        isSecure: false,
      );

      expect(result, isNotNull);
      expect(result!['name'], equals('test'));
      expect(result['count'], equals(42));
    });
  });

  group('saveSecure removes from normal box', () {
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

    test('should not attempt normal box removal when key not in normal box', () async {
      when(
        () => testContext.mockSecureBox.put(any<dynamic>(), any<dynamic>()),
      ).thenAnswer((_) async {});
      when(() => testContext.mockNormalBox.containsKey('only_secure')).thenReturn(false);

      await testContext.vaultStorage.saveSecure(key: 'only_secure', value: 'data');

      verifyNever(() => testContext.mockNormalBox.delete(any<dynamic>()));
    });
  });
}
