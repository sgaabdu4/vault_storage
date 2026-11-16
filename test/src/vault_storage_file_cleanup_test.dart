import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vault_storage/src/errors/errors.dart';
import 'package:vault_storage/src/storage/storage_strategy.dart';
import 'package:vault_storage/src/vault_storage_impl.dart';

import '../mocks.dart';
import '../test_context.dart';

class _IoFailure implements Exception {
  const _IoFailure();

  @override
  String toString() => '_IoFailure';
}

void main() {
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

      await testContext.vaultStorage.clearAllFilesInBox(.normalFiles, isSecure: false);

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

      await testContext.vaultStorage.clearAllFilesInBox(.secureFiles, isSecure: true);

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
      when(() => testContext.mockNormalFilesBox.containsKey(any<Object?>())).thenReturn(true);
      when(
        () => testContext.mockNormalFilesBox.get(any<Object?>()),
      ).thenAnswer((_) async => jsonMetadata);
      when(() => testContext.mockNormalFilesBox.clear()).thenAnswer((_) async => 0);

      // First file delete throws, second succeeds
      int callCount = 0;
      when(
        () => testContext.mockFileOperations.deleteNormalFile(
          fileMetadata: any(named: 'fileMetadata'),
          isWeb: any(named: 'isWeb'),
          getBox: any(named: 'getBox'),
        ),
      ).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) throw const _IoFailure();
      });

      // Should not throw despite first file failing
      await testContext.vaultStorage.clearAllFilesInBox(.normalFiles, isSecure: false);

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
      final mockCustomBox = MockBox<Object?>();
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
      final wrappedValue = const StoredValue('{"name":"test","count":42}', .json).toHiveMap();

      when(() => testContext.mockNormalBox.containsKey('json_val')).thenReturn(true);
      when(() => testContext.mockNormalBox.get('json_val')).thenReturn(wrappedValue);

      final result = await testContext.vaultStorage.get<Map<String, dynamic>>(
        'json_val',
        isSecure: false,
      );

      expect(result, isNotNull);
      expect(result?['name'], equals('test'));
      expect(result?['count'], equals(42));
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
        () => testContext.mockSecureBox.put(any<Object?>(), any<Object?>()),
      ).thenAnswer((_) async {});
      when(() => testContext.mockNormalBox.containsKey('only_secure')).thenReturn(false);

      await testContext.vaultStorage.saveSecure(key: 'only_secure', value: 'data');

      verifyNever(() => testContext.mockNormalBox.delete(any<Object?>()));
    });
  });

  group('VaultStorageImpl', () {
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

    group('saveSecureFile', () {
      test('should save secure file successfully', () async {
        // Arrange
        const key = 'test_file';
        final content = Uint8List.fromList([1, 2, 3, 4, 5]);
        const fileName = 'test.txt';
        final mockMetadata = {'fileId': 'test-id', 'extension': 'txt'};

        when(
          () => testContext.mockFileOperations.saveSecureFile(any()),
        ).thenAnswer((_) async => mockMetadata);
        when(
          () => testContext.mockSecureFilesBox.put(any<String>(), any<String>()),
        ).thenAnswer((_) async {});

        // Act
        await testContext.vaultStorage.saveSecureFile(
          key: key,
          fileBytes: content,
          originalFileName: fileName,
        );

        // Assert
        verify(
          () => testContext.mockFileOperations.saveSecureFile(secureRequestFor(content, 'txt')),
        ).called(1);
        verify(() => testContext.mockSecureFilesBox.put(key, any<Object?>())).called(1);
      });

      test('should throw StorageWriteError when file save fails', () async {
        // Arrange
        const key = 'test_file';
        final content = Uint8List.fromList([1, 2, 3, 4, 5]);

        when(
          () => testContext.mockFileOperations.saveSecureFile(any()),
        ).thenThrow(Exception('File save failed'));

        // Act & Assert
        expect(
          () => testContext.vaultStorage.saveSecureFile(key: key, fileBytes: content),
          throwsA(isA<StorageWriteError>()),
        );
      });
    });

    group('saveNormalFile', () {
      test('should save normal file successfully', () async {
        // Arrange
        const key = 'test_file';
        final content = Uint8List.fromList([1, 2, 3, 4, 5]);
        const fileName = 'test.txt';
        final mockMetadata = {'fileId': 'test-id', 'extension': 'txt'};

        when(
          () => testContext.mockFileOperations.saveNormalFile(any()),
        ).thenAnswer((_) async => mockMetadata);
        when(
          () => testContext.mockNormalFilesBox.put(any<String>(), any<String>()),
        ).thenAnswer((_) async {});

        // Act
        await testContext.vaultStorage.saveNormalFile(
          key: key,
          fileBytes: content,
          originalFileName: fileName,
        );

        // Assert
        verify(
          () => testContext.mockFileOperations.saveNormalFile(normalRequestFor(content, 'txt')),
        ).called(1);
        verify(() => testContext.mockNormalFilesBox.put(key, any<Object?>())).called(1);
      });
    });

    // No public streaming API; streaming is handled internally by saveSecureFile

    group('getFile', () {
      test('should get secure file successfully', () async {
        // Arrange
        const key = 'test_file';
        final expectedBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
        const jsonMetadata = '{"fileId":"test-id","isSecure":true}';

        when(() => testContext.mockSecureFilesBox.containsKey(key)).thenReturn(true);
        when(() => testContext.mockSecureFilesBox.get(key)).thenAnswer((_) async => jsonMetadata);
        when(
          () => testContext.mockFileOperations.getSecureFile(
            fileMetadata: any(named: 'fileMetadata'),
            isWeb: any(named: 'isWeb'),
            secureStorage: any(named: 'secureStorage'),
            getBox: any(named: 'getBox'),
          ),
        ).thenAnswer((_) async => expectedBytes);

        // Act
        final result = await testContext.vaultStorage.getFile(key, isSecure: true);

        // Assert
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

      test('should return null when file does not exist', () async {
        // Arrange
        const key = 'nonexistent_file';

        when(() => testContext.mockNormalFilesBox.containsKey(key)).thenReturn(false);
        when(() => testContext.mockSecureFilesBox.containsKey(key)).thenReturn(false);

        // Act
        final result = await testContext.vaultStorage.getFile(key);

        // Assert
        expect(result, isNull);
      });

      test('should throw StorageReadError when file retrieval fails', () async {
        // Arrange
        const key = 'test_file';
        const jsonMetadata = '{"fileId":"test-id","isSecure":true}';

        when(() => testContext.mockSecureFilesBox.containsKey(key)).thenReturn(true);
        when(() => testContext.mockSecureFilesBox.get(key)).thenAnswer((_) async => jsonMetadata);
        when(
          () => testContext.mockFileOperations.getSecureFile(
            fileMetadata: any(named: 'fileMetadata'),
            isWeb: any(named: 'isWeb'),
            secureStorage: any(named: 'secureStorage'),
            getBox: any(named: 'getBox'),
          ),
        ).thenThrow(Exception('File retrieval failed'));

        // Act & Assert
        expect(
          () => testContext.vaultStorage.getFile(key, isSecure: true),
          throwsA(isA<StorageReadError>()),
        );
      });
    });

    group('deleteFile', () {
      test('should delete file from both storages when it exists in both', () async {
        // Arrange
        const key = 'test_file';

        // Provide JSON metadata for both normal and secure file entries
        const normalJson = '{"fileId":"normal-id","extension":"txt"}';
        const secureJson =
            '{"fileId":"secure-id","secureKeyName":"file_key_secure-id","nonce":"bnVsbA==","mac":"bnVsbA=="}';

        when(() => testContext.mockNormalFilesBox.containsKey(key)).thenReturn(true);
        when(() => testContext.mockNormalFilesBox.get(key)).thenAnswer((_) async => normalJson);
        when(() => testContext.mockSecureFilesBox.containsKey(key)).thenReturn(true);
        when(() => testContext.mockSecureFilesBox.get(key)).thenAnswer((_) async => secureJson);

        // Underlying deletions
        when(
          () => testContext.mockFileOperations.deleteNormalFile(
            fileMetadata: any(named: 'fileMetadata'),
            isWeb: any(named: 'isWeb'),
            getBox: any(named: 'getBox'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => testContext.mockFileOperations.deleteSecureFile(
            fileMetadata: any(named: 'fileMetadata'),
            isWeb: any(named: 'isWeb'),
            secureStorage: any(named: 'secureStorage'),
            getBox: any(named: 'getBox'),
          ),
        ).thenAnswer((_) async {});

        // Metadata deletions
        when(() => testContext.mockNormalFilesBox.delete(key)).thenAnswer((_) async {});
        when(() => testContext.mockSecureFilesBox.delete(key)).thenAnswer((_) async {});

        // Act
        await testContext.vaultStorage.deleteFile(key);

        // Assert
        verify(() => testContext.mockNormalFilesBox.delete(key)).called(1);
        verify(() => testContext.mockSecureFilesBox.delete(key)).called(1);
      });

      test('should throw StorageDeleteError when deletion fails', () async {
        // Arrange
        const key = 'test_file';

        // Provide minimal metadata for normal
        const normalJson = '{"fileId":"normal-id","extension":"txt"}';
        when(() => testContext.mockNormalFilesBox.containsKey(key)).thenReturn(true);
        when(() => testContext.mockNormalFilesBox.get(key)).thenAnswer((_) async => normalJson);
        when(() => testContext.mockSecureFilesBox.containsKey(key)).thenReturn(false);

        // Underlying normal file deletion succeeds
        when(
          () => testContext.mockFileOperations.deleteNormalFile(
            fileMetadata: any(named: 'fileMetadata'),
            isWeb: any(named: 'isWeb'),
            getBox: any(named: 'getBox'),
          ),
        ).thenAnswer((_) async {});

        // Metadata delete throws
        when(
          () => testContext.mockNormalFilesBox.delete(key),
        ).thenThrow(Exception('Database error'));

        // Act & Assert
        expect(() => testContext.vaultStorage.deleteFile(key), throwsA(isA<StorageDeleteError>()));
      });
    });
  });
}
