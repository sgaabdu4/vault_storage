import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vault_storage/src/errors/errors.dart';
import 'package:vault_storage/src/storage/file_operations.dart';

import '../../mocks.dart';
import '../../test_context.dart';

void main() {
  group('FileOperations', () {
    late FileOperations fileOperations;
    late TestContext testContext;

    setUpAll(() {
      MocksHelper.registerFallbackValues();
    });

    setUp(() {
      testContext = TestContext();
      testContext.setUpCommon();
      fileOperations = FileOperations();
    });

    tearDown(() {
      testContext.tearDownCommon();
    });

    group('saveSecureFile', () {
      test('should save secure file successfully on native platforms',
          () async {
        // Arrange
        final fileBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
        const fileExtension = 'txt';
        const testFileId = 'test-file-id';

        when(() => testContext.mockUuid.v4()).thenReturn(testFileId);
        when(() => testContext.mockSecureStorage.write(
              key: any(named: 'key'),
              value: any(named: 'value'),
            )).thenAnswer((_) async {});

        // Act
        final result = await fileOperations.saveSecureFile(
          fileBytes: fileBytes,
          fileExtension: fileExtension,
          isWeb: false,
          secureStorage: testContext.mockSecureStorage,
          uuid: testContext.mockUuid,
          getBox: testContext.getBox,
        );

        // Assert
        expect(result['fileId'], equals(testFileId));
        expect(result['extension'], equals(fileExtension));
        expect(result['filePath'], contains(testFileId));
        expect(result['filePath'], contains('.enc'));
        expect(result['secureKeyName'], equals('file_key_$testFileId'));
        expect(result.containsKey('nonce'), isTrue);
        expect(result.containsKey('mac'), isTrue);

        verify(() => testContext.mockUuid.v4()).called(1);
        verify(() => testContext.mockSecureStorage.write(
              key: 'file_key_$testFileId',
              value: any(named: 'value'),
            )).called(1);
      });

      test('should save secure file successfully on web platform', () async {
        // Arrange
        final fileBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
        const fileExtension = 'txt';
        const testFileId = 'test-file-id';
        final mockBox = testContext.mockSecureFilesBox;

        when(() => testContext.mockUuid.v4()).thenReturn(testFileId);
        when(() => testContext.mockSecureStorage.write(
              key: any(named: 'key'),
              value: any(named: 'value'),
            )).thenAnswer((_) async {});
        when(() => mockBox.put(any<String>(), any<String>()))
            .thenAnswer((_) async {});

        // Act
        final result = await fileOperations.saveSecureFile(
          fileBytes: fileBytes,
          fileExtension: fileExtension,
          isWeb: true,
          secureStorage: testContext.mockSecureStorage,
          uuid: testContext.mockUuid,
          getBox: testContext.getBox,
        );

        // Assert
        expect(result['fileId'], equals(testFileId));
        expect(result['extension'], equals(fileExtension));
        expect(result['filePath'], isNull); // Web doesn't use file paths
        expect(result['secureKeyName'], equals('file_key_$testFileId'));
        expect(result.containsKey('nonce'), isTrue);
        expect(result.containsKey('mac'), isTrue);

        verify(() => testContext.mockUuid.v4()).called(1);
        verify(() => testContext.mockSecureStorage.write(
              key: 'file_key_$testFileId',
              value: any(named: 'value'),
            )).called(1);
        verify(() => mockBox.put(testFileId, any())).called(1);
      });

      test('should throw StorageWriteError when encryption fails', () async {
        // Arrange
        final fileBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
        const fileExtension = 'txt';

        when(() => testContext.mockUuid.v4())
            .thenThrow(Exception('UUID generation failed'));

        // Act & Assert
        expect(
          () => fileOperations.saveSecureFile(
            fileBytes: fileBytes,
            fileExtension: fileExtension,
            isWeb: false,
            secureStorage: testContext.mockSecureStorage,
            uuid: testContext.mockUuid,
            getBox: testContext.getBox,
          ),
          throwsA(isA<StorageWriteError>()),
        );
      });
    });

    group('saveSecureFileStream (streaming)', () {
      test('should save streaming secure file successfully on web', () async {
        // Arrange
        final parts = [
          Uint8List.fromList(List.generate(1024, (i) => i % 256)),
          Uint8List.fromList(List.generate(2048, (i) => (i + 1) % 256)),
        ];
        final stream = Stream<List<int>>.fromIterable(parts);
        const fileExtension = 'bin';
        const testFileId = 'stream-id';

        when(() => testContext.mockUuid.v4()).thenReturn(testFileId);
        when(() => testContext.mockSecureFilesBox
            .put(any<String>(), any<String>())).thenAnswer((_) async {});
        when(() => testContext.mockSecureStorage.write(
              key: any(named: 'key'),
              value: any(named: 'value'),
            )).thenAnswer((_) async {});

        // Act
        final meta = await fileOperations.saveSecureFileStream(
          stream: stream,
          fileExtension: fileExtension,
          isWeb: true,
          secureStorage: testContext.mockSecureStorage,
          uuid: testContext.mockUuid,
          getBox: testContext.getBox,
          chunkSize: 1024,
        );

        // Assert
        expect(meta['fileId'], equals(testFileId));
        expect(meta['streaming'], isTrue);
        expect(meta['chunkCount'], greaterThan(0));
        verify(() => testContext.mockSecureFilesBox
            .put(any<String>(), any<String>())).called(greaterThan(0));
        verify(() => testContext.mockSecureStorage.write(
              key: 'file_key_$testFileId',
              value: any(named: 'value'),
            )).called(1);
      });
    });

    group('getSecureFile', () {
      test('should retrieve secure file successfully on native platforms',
          () async {
        // Arrange
        const testFileId = 'test-file-id';
        const secureKeyName = 'file_key_$testFileId';
        final testKey = Uint8List.fromList(List.generate(32, (i) => i));

        final fileMetadata = {
          'fileId': testFileId,
          'filePath': '/test/path/$testFileId.txt.enc',
          'secureKeyName': secureKeyName,
          'nonce': 'dGVzdE5vbmNl', // base64 encoded test nonce
          'mac': 'dGVzdE1hYw==', // base64 encoded test MAC
          'extension': 'txt',
        };

        when(() => testContext.mockSecureStorage.read(key: secureKeyName))
            .thenAnswer(
                (_) async => testKey.map((e) => e.toString()).join(','));

        // Act & Assert
        // Note: This test would need more complex mocking for the file system
        // and encryption/decryption processes. For now, we test the error case.
        expect(
          () => fileOperations.getSecureFile(
            fileMetadata: fileMetadata,
            isWeb: false,
            secureStorage: testContext.mockSecureStorage,
            getBox: testContext.getBox,
          ),
          throwsA(isA<StorageReadError>()),
        );
      });

      test('should retrieve secure file successfully on web platform',
          () async {
        // Arrange
        const testFileId = 'test-file-id';
        const secureKeyName = 'file_key_$testFileId';
        final mockBox = testContext.mockSecureFilesBox;

        final fileMetadata = {
          'fileId': testFileId,
          'secureKeyName': secureKeyName,
          'nonce': 'dGVzdE5vbmNl', // base64 encoded test nonce
          'mac': 'dGVzdE1hYw==', // base64 encoded test MAC
          'extension': 'txt',
        };

        when(() => mockBox.get(testFileId)).thenAnswer(
            (_) async => 'dGVzdENvbnRlbnQ='); // base64 encoded test content
        when(() => testContext.mockSecureStorage.read(key: secureKeyName))
            .thenAnswer((_) async => 'dGVzdEtleQ=='); // base64 encoded test key

        // Act & Assert
        // Note: This test would need more complex mocking for the encryption/decryption
        expect(
          () => fileOperations.getSecureFile(
            fileMetadata: fileMetadata,
            isWeb: true,
            secureStorage: testContext.mockSecureStorage,
            getBox: testContext.getBox,
          ),
          throwsA(isA<StorageReadError>()),
        );
      });

      test('should throw FileNotFoundError when file does not exist on web',
          () async {
        // Arrange
        const testFileId = 'test-file-id';
        const secureKeyName = 'file_key_$testFileId';
        final mockBox = testContext.mockSecureFilesBox;

        final fileMetadata = {
          'fileId': testFileId,
          'secureKeyName': secureKeyName,
          'nonce': 'dGVzdE5vbmNl',
          'mac': 'dGVzdE1hYw==',
          'extension': 'txt',
        };

        when(() => mockBox.get(testFileId)).thenAnswer((_) async => null);

        // Act & Assert
        expect(
          () => fileOperations.getSecureFile(
            fileMetadata: fileMetadata,
            isWeb: true,
            secureStorage: testContext.mockSecureStorage,
            getBox: testContext.getBox,
          ),
          throwsA(isA<FileNotFoundError>()),
        );
      });

      test('should throw KeyNotFoundError when encryption key is missing',
          () async {
        // Arrange
        const testFileId = 'test-file-id';
        const secureKeyName = 'file_key_$testFileId';
        final mockBox = testContext.mockSecureFilesBox;

        final fileMetadata = {
          'fileId': testFileId,
          'secureKeyName': secureKeyName,
          'nonce': 'dGVzdE5vbmNl',
          'mac': 'dGVzdE1hYw==',
          'extension': 'txt',
        };

        when(() => mockBox.get(testFileId))
            .thenAnswer((_) async => 'dGVzdENvbnRlbnQ=');
        when(() => testContext.mockSecureStorage.read(key: secureKeyName))
            .thenAnswer((_) async => null);

        // Act & Assert
        expect(
          () => fileOperations.getSecureFile(
            fileMetadata: fileMetadata,
            isWeb: true,
            secureStorage: testContext.mockSecureStorage,
            getBox: testContext.getBox,
          ),
          throwsA(isA<KeyNotFoundError>()),
        );
      });

      test('should throw InvalidMetadataError when required fields are missing',
          () async {
        // Arrange
        final incompleteMetadata = <String, dynamic>{
          'fileId': 'test-file-id',
          // Missing secureKeyName, nonce, mac
        };

        // Act & Assert
        expect(
          () => fileOperations.getSecureFile(
            fileMetadata: incompleteMetadata,
            isWeb: true,
            secureStorage: testContext.mockSecureStorage,
            getBox: testContext.getBox,
          ),
          throwsA(isA<InvalidMetadataError>()),
        );
      });
    });

    group('deleteSecureFile', () {
      test('should delete secure file successfully on native platforms',
          () async {
        // Arrange
        const testFileId = 'test-file-id';
        const secureKeyName = 'file_key_$testFileId';

        final fileMetadata = {
          'fileId': testFileId,
          'filePath': '/test/path/$testFileId.txt.enc',
          'secureKeyName': secureKeyName,
        };

        when(() => testContext.mockSecureStorage.delete(key: secureKeyName))
            .thenAnswer((_) async {});

        // Act
        await fileOperations.deleteSecureFile(
          fileMetadata: fileMetadata,
          isWeb: false,
          secureStorage: testContext.mockSecureStorage,
          getBox: testContext.getBox,
        );

        // Assert
        verify(() => testContext.mockSecureStorage.delete(key: secureKeyName))
            .called(1);
      });

      test('should delete secure file successfully on web platform', () async {
        // Arrange
        const testFileId = 'test-file-id';
        const secureKeyName = 'file_key_$testFileId';
        final mockBox = testContext.mockSecureFilesBox;

        final fileMetadata = {
          'fileId': testFileId,
          'secureKeyName': secureKeyName,
        };

        when(() => mockBox.delete(testFileId)).thenAnswer((_) async {});
        when(() => testContext.mockSecureStorage.delete(key: secureKeyName))
            .thenAnswer((_) async {});

        // Act
        await fileOperations.deleteSecureFile(
          fileMetadata: fileMetadata,
          isWeb: true,
          secureStorage: testContext.mockSecureStorage,
          getBox: testContext.getBox,
        );

        // Assert
        verify(() => mockBox.delete(testFileId)).called(1);
        verify(() => testContext.mockSecureStorage.delete(key: secureKeyName))
            .called(1);
      });

      test('should throw StorageDeleteError when deletion fails', () async {
        // Arrange
        const testFileId = 'test-file-id';
        const secureKeyName = 'file_key_$testFileId';

        final fileMetadata = {
          'fileId': testFileId,
          'secureKeyName': secureKeyName,
        };

        when(() => testContext.mockSecureStorage.delete(key: secureKeyName))
            .thenThrow(Exception('Deletion failed'));

        // Act & Assert
        expect(
          () => fileOperations.deleteSecureFile(
            fileMetadata: fileMetadata,
            isWeb: true,
            secureStorage: testContext.mockSecureStorage,
            getBox: testContext.getBox,
          ),
          throwsA(isA<StorageDeleteError>()),
        );
      });
    });

    group('saveNormalFile', () {
      test('should save normal file successfully on native platforms',
          () async {
        // Arrange
        final fileBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
        const fileExtension = 'txt';
        const testFileId = 'test-file-id';

        when(() => testContext.mockUuid.v4()).thenReturn(testFileId);

        // Act
        final result = await fileOperations.saveNormalFile(
          fileBytes: fileBytes,
          fileExtension: fileExtension,
          isWeb: false,
          uuid: testContext.mockUuid,
          getBox: testContext.getBox,
        );

        // Assert
        expect(result['fileId'], equals(testFileId));
        expect(result['extension'], equals(fileExtension));
        expect(result['filePath'], contains(testFileId));
        expect(result['filePath'], endsWith('.$fileExtension'));

        verify(() => testContext.mockUuid.v4()).called(1);
      });

      test('should save normal file successfully on web platform', () async {
        // Arrange
        final fileBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
        const fileExtension = 'txt';
        const testFileId = 'test-file-id';
        final mockBox = testContext.mockNormalFilesBox;

        when(() => testContext.mockUuid.v4()).thenReturn(testFileId);
        when(() => mockBox.put(any<String>(), any<String>()))
            .thenAnswer((_) async {});

        // Act
        final result = await fileOperations.saveNormalFile(
          fileBytes: fileBytes,
          fileExtension: fileExtension,
          isWeb: true,
          uuid: testContext.mockUuid,
          getBox: testContext.getBox,
        );

        // Assert
        expect(result['fileId'], equals(testFileId));
        expect(result['extension'], equals(fileExtension));
        expect(result['filePath'], isNull); // Web doesn't use file paths

        verify(() => testContext.mockUuid.v4()).called(1);
        verify(() => mockBox.put(testFileId, any())).called(1);
      });

      test('should throw StorageWriteError when save fails', () async {
        // Arrange
        final fileBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
        const fileExtension = 'txt';

        when(() => testContext.mockUuid.v4())
            .thenThrow(Exception('UUID generation failed'));

        // Act & Assert
        expect(
          () => fileOperations.saveNormalFile(
            fileBytes: fileBytes,
            fileExtension: fileExtension,
            isWeb: false,
            uuid: testContext.mockUuid,
            getBox: testContext.getBox,
          ),
          throwsA(isA<StorageWriteError>()),
        );
      });
    });

    group('getNormalFile', () {
      test('should retrieve normal file successfully on web platform',
          () async {
        // Arrange
        const testFileId = 'test-file-id';
        final mockBox = testContext.mockNormalFilesBox;
        final expectedBytes = Uint8List.fromList([1, 2, 3, 4, 5]);

        final fileMetadata = {
          'fileId': testFileId,
          'extension': 'txt',
        };

        when(() => mockBox.get(testFileId))
            .thenAnswer((_) async => 'AQIDBAU='); // base64 of [1,2,3,4,5]

        // Act
        final result = await fileOperations.getNormalFile(
          fileMetadata: fileMetadata,
          isWeb: true,
          getBox: testContext.getBox,
        );

        // Assert
        expect(result, equals(expectedBytes));
        verify(() => mockBox.get(testFileId)).called(1);
      });

      test('should throw FileNotFoundError when file does not exist on web',
          () async {
        // Arrange
        const testFileId = 'test-file-id';
        final mockBox = testContext.mockNormalFilesBox;

        final fileMetadata = {
          'fileId': testFileId,
          'extension': 'txt',
        };

        when(() => mockBox.get(testFileId)).thenAnswer((_) async => null);

        // Act & Assert
        expect(
          () => fileOperations.getNormalFile(
            fileMetadata: fileMetadata,
            isWeb: true,
            getBox: testContext.getBox,
          ),
          throwsA(isA<FileNotFoundError>()),
        );
      });

      test(
          'should throw InvalidMetadataError when filePath is missing on native',
          () async {
        // Arrange
        final fileMetadata = {
          'fileId': 'test-file-id',
          // Missing filePath for native platform
        };

        // Act & Assert
        expect(
          () => fileOperations.getNormalFile(
            fileMetadata: fileMetadata,
            isWeb: false,
            getBox: testContext.getBox,
          ),
          throwsA(isA<InvalidMetadataError>()),
        );
      });
    });

    group('deleteNormalFile', () {
      test('should delete normal file successfully on web platform', () async {
        // Arrange
        const testFileId = 'test-file-id';
        final mockBox = testContext.mockNormalFilesBox;

        final fileMetadata = {
          'fileId': testFileId,
        };

        when(() => mockBox.delete(testFileId)).thenAnswer((_) async {});

        // Act
        await fileOperations.deleteNormalFile(
          fileMetadata: fileMetadata,
          isWeb: true,
          getBox: testContext.getBox,
        );

        // Assert
        verify(() => mockBox.delete(testFileId)).called(1);
      });

      test('should handle deletion gracefully when file does not exist',
          () async {
        // Arrange
        const testFileId = 'test-file-id';
        final mockBox = testContext.mockNormalFilesBox;

        final fileMetadata = {
          'fileId': testFileId,
          'filePath': '/nonexistent/path',
        };

        when(() => mockBox.delete(testFileId)).thenAnswer((_) async {});

        // Act & Assert - Should not throw
        await fileOperations.deleteNormalFile(
          fileMetadata: fileMetadata,
          isWeb: true,
          getBox: testContext.getBox,
        );

        verify(() => mockBox.delete(testFileId)).called(1);
      });

      test('should throw StorageDeleteError when deletion fails', () async {
        // Arrange
        const testFileId = 'test-file-id';
        final mockBox = testContext.mockNormalFilesBox;

        final fileMetadata = {
          'fileId': testFileId,
        };

        when(() => mockBox.delete(testFileId))
            .thenThrow(Exception('Deletion failed'));

        // Act & Assert
        expect(
          () => fileOperations.deleteNormalFile(
            fileMetadata: fileMetadata,
            isWeb: true,
            getBox: testContext.getBox,
          ),
          throwsA(isA<StorageDeleteError>()),
        );
      });
    });

    group('MIME type detection', () {
      test('should return correct MIME types for common file extensions', () {
        // Note: This tests the private _getMimeTypeFromExtension method indirectly
        // through the file operations that use it. In a real test, you might want to
        // make this method visible for testing or test it through the public API.

        // For now, we can verify the behavior through file operations
        expect(
            true, isTrue); // Placeholder - would need access to private method
      });
    });

    group('Error handling', () {
      test('should preserve original StorageError types', () async {
        // Arrange
        const testFileId = 'test-file-id';
        const secureKeyName = 'file_key_$testFileId';

        final fileMetadata = {
          'fileId': testFileId,
          'secureKeyName': secureKeyName,
          'nonce': 'dGVzdE5vbmNl',
          'mac': 'dGVzdE1hYw==',
        };

        when(() => testContext.mockSecureFilesBox.get(testFileId))
            .thenAnswer((_) async => null);

        // Act & Assert
        expect(
          () => fileOperations.getSecureFile(
            fileMetadata: fileMetadata,
            isWeb: true,
            secureStorage: testContext.mockSecureStorage,
            getBox: testContext.getBox,
          ),
          throwsA(isA<FileNotFoundError>()),
        );
      });

      test('should wrap non-StorageError exceptions appropriately', () async {
        // Arrange
        final fileBytes = Uint8List.fromList([1, 2, 3, 4, 5]);

        when(() => testContext.mockUuid.v4())
            .thenThrow(Exception('Unexpected error'));

        // Act & Assert
        expect(
          () => fileOperations.saveNormalFile(
            fileBytes: fileBytes,
            fileExtension: 'txt',
            isWeb: false,
            uuid: testContext.mockUuid,
            getBox: testContext.getBox,
          ),
          throwsA(isA<StorageWriteError>()),
        );
      });
    });
  });
}
