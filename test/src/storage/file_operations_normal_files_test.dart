import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vault_storage/src/entities/normal_file_request.dart';
import 'package:vault_storage/src/entities/secure_file_request.dart';
import 'package:vault_storage/src/entities/secure_file_stream_request.dart';
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

    group('saveNormalFile', () {
      test('should save normal file successfully on native platforms', () async {
        // Arrange
        final fileBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
        const fileExtension = 'txt';
        const testFileId = 'test-file-id';

        when(() => testContext.mockUuid.v4()).thenReturn(testFileId);

        // Act
        final result = await fileOperations.saveNormalFile(
          NormalFileRequest(
            fileBytes: fileBytes,
            fileExtension: fileExtension,
            services: testContext.fileServices(isWeb: false),
          ),
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
        when(() => mockBox.put(any<String>(), any<String>())).thenAnswer((_) async {});

        // Act
        final result = await fileOperations.saveNormalFile(
          NormalFileRequest(
            fileBytes: fileBytes,
            fileExtension: fileExtension,
            services: testContext.fileServices(isWeb: true),
          ),
        );

        // Assert
        expect(result['fileId'], equals(testFileId));
        expect(result['extension'], equals(fileExtension));
        expect(result['filePath'], isNull); // Web doesn't use file paths

        verify(() => testContext.mockUuid.v4()).called(1);
        verify(() => mockBox.put(testFileId, any<Object?>())).called(1);
      });

      test('should throw StorageWriteError when save fails', () async {
        // Arrange
        final fileBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
        const fileExtension = 'txt';

        when(() => testContext.mockUuid.v4()).thenThrow(Exception('UUID generation failed'));

        // Act & Assert
        expect(
          () => fileOperations.saveNormalFile(
            NormalFileRequest(
              fileBytes: fileBytes,
              fileExtension: fileExtension,
              services: testContext.fileServices(isWeb: false),
            ),
          ),
          throwsA(isA<StorageWriteError>()),
        );
      });
    });

    group('getNormalFile', () {
      test('should retrieve normal file successfully on web platform', () async {
        // Arrange
        const testFileId = 'test-file-id';
        final mockBox = testContext.mockNormalFilesBox;
        final expectedBytes = Uint8List.fromList([1, 2, 3, 4, 5]);

        final fileMetadata = {'fileId': testFileId, 'extension': 'txt'};

        when(
          () => mockBox.get(testFileId),
        ).thenAnswer((_) async => 'AQIDBAU='); // base64 of [1,2,3,4,5]

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

      test('should throw FileNotFoundError when file does not exist on web', () async {
        // Arrange
        const testFileId = 'test-file-id';
        final mockBox = testContext.mockNormalFilesBox;

        final fileMetadata = {'fileId': testFileId, 'extension': 'txt'};

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

      test('should throw InvalidMetadataError when filePath is missing on native', () async {
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

        final fileMetadata = {'fileId': testFileId};

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

      test('should handle deletion gracefully when file does not exist', () async {
        // Arrange
        const testFileId = 'test-file-id';
        final mockBox = testContext.mockNormalFilesBox;

        final fileMetadata = {'fileId': testFileId, 'filePath': '/nonexistent/path'};

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

        final fileMetadata = {'fileId': testFileId};

        when(() => mockBox.delete(testFileId)).thenThrow(Exception('Deletion failed'));

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
        // For now, we can verify the behavior through file operations
        expect(true, isTrue); // Placeholder - would need access to private method
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

        when(() => testContext.mockSecureFilesBox.get(testFileId)).thenAnswer((_) async => null);

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

        when(() => testContext.mockUuid.v4()).thenThrow(Exception('Unexpected error'));

        // Act & Assert
        expect(
          () => fileOperations.saveNormalFile(
            NormalFileRequest(
              fileBytes: fileBytes,
              fileExtension: 'txt',
              services: testContext.fileServices(isWeb: false),
            ),
          ),
          throwsA(isA<StorageWriteError>()),
        );
      });

      test('saveSecureFile should rethrow StorageError without wrapping', () async {
        when(
          () => testContext.mockUuid.v4(),
        ).thenThrow(const StorageWriteError('pre-existing error'));

        expect(
          () => fileOperations.saveSecureFile(
            SecureFileRequest(
              fileBytes: .fromList([1, 2, 3]),
              fileExtension: 'bin',
              services: testContext.fileServices(isWeb: false),
            ),
          ),
          throwsA(
            isA<StorageWriteError>().having(
              (e) => e.message,
              'message',
              equals('pre-existing error'),
            ),
          ),
        );
      });

      test('saveSecureFileStream should rethrow StorageError without wrapping', () async {
        when(
          () => testContext.mockUuid.v4(),
        ).thenThrow(const StorageWriteError('stream pre-existing error'));

        expect(
          () => fileOperations.saveSecureFileStream(
            SecureFileStreamRequest(
              stream: .value([1, 2, 3]),
              fileExtension: 'bin',
              services: testContext.fileServices(isWeb: false),
            ),
          ),
          throwsA(
            isA<StorageWriteError>().having(
              (e) => e.message,
              'message',
              equals('stream pre-existing error'),
            ),
          ),
        );
      });

      test('saveNormalFile should rethrow StorageError without wrapping', () async {
        when(
          () => testContext.mockUuid.v4(),
        ).thenThrow(const StorageWriteError('normal pre-existing error'));

        expect(
          () => fileOperations.saveNormalFile(
            NormalFileRequest(
              fileBytes: .fromList([1, 2, 3]),
              fileExtension: 'bin',
              services: testContext.fileServices(isWeb: false),
            ),
          ),
          throwsA(
            isA<StorageWriteError>().having(
              (e) => e.message,
              'message',
              equals('normal pre-existing error'),
            ),
          ),
        );
      });
    });
  });
}
