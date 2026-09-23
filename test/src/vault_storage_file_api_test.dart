import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vault_storage/src/errors/errors.dart';

import '../mocks.dart';
import '../test_context.dart';

void main() {
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
        final fileBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
        const fileName = 'test.txt';
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
          () => testContext.mockSecureFilesBox.put(any<String>(), any<String>()),
        ).thenAnswer((_) async {});

        // Act
        await testContext.vaultStorage.saveSecureFile(
          key: key,
          fileBytes: fileBytes,
          originalFileName: fileName,
        );

        // Assert
        verify(
          () => testContext.mockFileOperations.saveSecureFile(
            fileBytes: fileBytes,
            fileExtension: 'txt',
            isWeb: any(named: 'isWeb'),
            secureStorage: any(named: 'secureStorage'),
            uuid: any(named: 'uuid'),
            getBox: any(named: 'getBox'),
          ),
        ).called(1);
        verify(() => testContext.mockSecureFilesBox.put(key, any<dynamic>())).called(1);
      });

      test('should throw StorageWriteError when file save fails', () async {
        // Arrange
        const key = 'test_file';
        final fileBytes = Uint8List.fromList([1, 2, 3, 4, 5]);

        when(
          () => testContext.mockFileOperations.saveSecureFile(
            fileBytes: any(named: 'fileBytes'),
            fileExtension: any(named: 'fileExtension'),
            isWeb: any(named: 'isWeb'),
            secureStorage: any(named: 'secureStorage'),
            uuid: any(named: 'uuid'),
            getBox: any(named: 'getBox'),
          ),
        ).thenThrow(Exception('File save failed'));

        // Act & Assert
        expect(
          () => testContext.vaultStorage.saveSecureFile(key: key, fileBytes: fileBytes),
          throwsA(isA<StorageWriteError>()),
        );
      });
    });

    group('saveNormalFile', () {
      test('should save normal file successfully', () async {
        // Arrange
        const key = 'test_file';
        final fileBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
        const fileName = 'test.txt';
        final mockMetadata = {'fileId': 'test-id', 'extension': 'txt'};

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
          () => testContext.mockNormalFilesBox.put(any<String>(), any<String>()),
        ).thenAnswer((_) async {});

        // Act
        await testContext.vaultStorage.saveNormalFile(
          key: key,
          fileBytes: fileBytes,
          originalFileName: fileName,
        );

        // Assert
        verify(
          () => testContext.mockFileOperations.saveNormalFile(
            fileBytes: fileBytes,
            fileExtension: 'txt',
            isWeb: any(named: 'isWeb'),
            uuid: any(named: 'uuid'),
            getBox: any(named: 'getBox'),
          ),
        ).called(1);
        verify(() => testContext.mockNormalFilesBox.put(key, any<dynamic>())).called(1);
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
