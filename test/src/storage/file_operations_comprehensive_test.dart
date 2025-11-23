import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vault_storage/src/errors/errors.dart';
import 'package:vault_storage/src/storage/file_operations.dart';

import '../../mocks.dart';
import '../../test_context.dart';

void main() {
  group('FileOperations - Comprehensive Tests', () {
    late FileOperations fileOperations;
    late TestContext testContext;
    late Directory tempDir;

    setUpAll(() {
      MocksHelper.registerFallbackValues();
    });

    setUp(() async {
      testContext = TestContext();
      testContext.setUpCommon();
      fileOperations = FileOperations();

      // Create a temporary directory for file operations
      tempDir = await Directory.systemTemp.createTemp('vault_storage_test');

      // Mock path_provider to return the temporary directory
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      TestWidgetsFlutterBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (MethodCall methodCall) async {
          if (methodCall.method == 'getApplicationDocumentsDirectory') {
            return tempDir.path;
          }
          return null;
        },
      );
    });

    tearDown(() async {
      testContext.tearDownCommon();
      // Clean up the temporary directory
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    group('saveSecureFile', () {
      test('should handle basic inputs correctly', () async {
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
          isWeb: false, // Use native to avoid web-specific issues
          secureStorage: testContext.mockSecureStorage,
          uuid: testContext.mockUuid,
          getBox: testContext.getBox,
        );

        // Assert
        expect(result['fileId'], equals(testFileId));
        expect(result['extension'], equals(fileExtension));
        expect(result['filePath'], isNotNull);
        expect(result['filePath'], contains(testFileId));
        expect(result['filePath'], endsWith('.enc'));
        expect(result['secureKeyName'], equals('file_key_$testFileId'));
        expect(result.containsKey('nonce'), isTrue);
        expect(result.containsKey('mac'), isTrue);

        verify(() => testContext.mockUuid.v4()).called(1);
        verify(() => testContext.mockSecureStorage.write(
              key: 'file_key_$testFileId',
              value: any(named: 'value'),
            )).called(1);
      });

      test('should validate required parameters', () {
        // Test that the method properly validates its inputs
        expect(
          () => fileOperations.saveSecureFile(
            fileBytes: Uint8List(0), // Empty bytes
            fileExtension: '',
            isWeb: true,
            secureStorage: testContext.mockSecureStorage,
            uuid: testContext.mockUuid,
            getBox: testContext.getBox,
          ),
          throwsA(isA<StorageWriteError>()),
        );
      });
    });

    group('getSecureFile', () {
      test('should throw InvalidMetadataError for missing required fields', () async {
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

      test('should throw FileNotFoundError when file does not exist on web', () async {
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

      test('should throw KeyNotFoundError when encryption key is missing', () async {
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

      test('should throw InvalidMetadataError when filePath is missing on native', () async {
        // Arrange
        const testFileId = 'test-file-id';
        const secureKeyName = 'file_key_$testFileId';

        final fileMetadata = {
          'fileId': testFileId,
          'secureKeyName': secureKeyName,
          'nonce': 'dGVzdE5vbmNl',
          'mac': 'dGVzdE1hYw==',
          // Missing filePath for native platform
        };

        // Act & Assert
        expect(
          () => fileOperations.getSecureFile(
            fileMetadata: fileMetadata,
            isWeb: false,
            secureStorage: testContext.mockSecureStorage,
            getBox: testContext.getBox,
          ),
          throwsA(isA<InvalidMetadataError>()),
        );
      });
    });

    group('deleteSecureFile', () {
      test('should call storage operations correctly for web', () async {
        // Arrange
        const testFileId = 'test-file-id';
        const secureKeyName = 'file_key_$testFileId';

        final fileMetadata = {
          'fileId': testFileId,
          'secureKeyName': secureKeyName,
        };

        when(() => testContext.mockSecureFilesBox.delete(testFileId)).thenAnswer((_) async {});
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
        verify(() => testContext.mockSecureFilesBox.delete(testFileId)).called(1);
        verify(() => testContext.mockSecureStorage.delete(key: secureKeyName)).called(1);
      });

      test('should handle InvalidMetadataError for missing fileId', () async {
        // Arrange
        final incompleteMetadata = <String, dynamic>{
          'secureKeyName': 'some-key',
          // Missing fileId
        };

        // Act & Assert
        expect(
          () => fileOperations.deleteSecureFile(
            fileMetadata: incompleteMetadata,
            isWeb: true,
            secureStorage: testContext.mockSecureStorage,
            getBox: testContext.getBox,
          ),
          throwsA(isA<InvalidMetadataError>()),
        );
      });
    });

    group('saveNormalFile', () {
      test('should handle basic inputs correctly for web', () async {
        // Arrange
        final fileBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
        const fileExtension = 'txt';
        const testFileId = 'test-file-id';

        when(() => testContext.mockUuid.v4()).thenReturn(testFileId);
        when(() => testContext.mockNormalFilesBox.put(any<String>(), any<String>()))
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
        verify(() => testContext.mockNormalFilesBox.put(testFileId, any<String>())).called(1);
      });

      test('should generate proper metadata for native', () async {
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
        expect(result['filePath'], isNotNull); // Native should have file path
        expect(result['filePath'], contains(testFileId));
        expect(result['filePath'], endsWith('.$fileExtension'));

        verify(() => testContext.mockUuid.v4()).called(1);
      });
    });

    group('getNormalFile', () {
      test('should retrieve normal file successfully on web platform', () async {
        // Arrange
        const testFileId = 'test-file-id';
        final expectedBytes = Uint8List.fromList([1, 2, 3, 4, 5]);

        final fileMetadata = {
          'fileId': testFileId,
          'extension': 'txt',
        };

        when(() => testContext.mockNormalFilesBox.get(testFileId))
            .thenAnswer((_) async => 'AQIDBAU='); // base64 of [1,2,3,4,5]

        // Act
        final result = await fileOperations.getNormalFile(
          fileMetadata: fileMetadata,
          isWeb: true,
          getBox: testContext.getBox,
        );

        // Assert
        expect(result, equals(expectedBytes));
        verify(() => testContext.mockNormalFilesBox.get(testFileId)).called(1);
      });

      test('should throw FileNotFoundError when file does not exist on web', () async {
        // Arrange
        const testFileId = 'test-file-id';

        final fileMetadata = {
          'fileId': testFileId,
          'extension': 'txt',
        };

        when(() => testContext.mockNormalFilesBox.get(testFileId)).thenAnswer((_) async => null);

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

        final fileMetadata = {
          'fileId': testFileId,
        };

        when(() => testContext.mockNormalFilesBox.delete(testFileId)).thenAnswer((_) async {});

        // Act
        await fileOperations.deleteNormalFile(
          fileMetadata: fileMetadata,
          isWeb: true,
          getBox: testContext.getBox,
        );

        // Assert
        verify(() => testContext.mockNormalFilesBox.delete(testFileId)).called(1);
      });

      test('should handle deletion gracefully when file does not exist', () async {
        // Arrange
        const testFileId = 'test-file-id';

        final fileMetadata = {
          'fileId': testFileId,
          'filePath': '/nonexistent/path',
        };

        when(() => testContext.mockNormalFilesBox.delete(testFileId)).thenAnswer((_) async {});

        // Act & Assert - Should not throw
        await fileOperations.deleteNormalFile(
          fileMetadata: fileMetadata,
          isWeb: true,
          getBox: testContext.getBox,
        );

        verify(() => testContext.mockNormalFilesBox.delete(testFileId)).called(1);
      });

      test('should throw InvalidMetadataError for missing fileId', () async {
        // Arrange
        final incompleteMetadata = <String, dynamic>{
          'filePath': '/some/path',
          // Missing fileId
        };

        // Act & Assert
        expect(
          () => fileOperations.deleteNormalFile(
            fileMetadata: incompleteMetadata,
            isWeb: true,
            getBox: testContext.getBox,
          ),
          throwsA(isA<InvalidMetadataError>()),
        );
      });
    });

    group('Error handling and edge cases', () {
      test('should wrap non-StorageError exceptions appropriately in saveNormalFile', () async {
        // Arrange
        final fileBytes = Uint8List.fromList([1, 2, 3, 4, 5]);

        when(() => testContext.mockUuid.v4()).thenThrow(Exception('Unexpected error'));

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

      test('should handle storage operation failures gracefully', () async {
        // Arrange
        const testFileId = 'test-file-id';

        final fileMetadata = {
          'fileId': testFileId,
        };

        when(() => testContext.mockNormalFilesBox.delete(testFileId))
            .thenThrow(Exception('Storage operation failed'));

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
    });
  });
}
