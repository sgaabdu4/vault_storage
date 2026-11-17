import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vault_storage/src/entities/secure_file_stream_request.dart';
import 'package:vault_storage/src/errors/errors.dart';
import 'package:vault_storage/src/storage/file_operations.dart';

import '../../helpers/invocation_arguments.dart';
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

    group('getSecureFile', () {
      test('should read streamed web metadata without single-file nonce fields', () async {
        final storedChunks = <String, dynamic>{};
        String? encodedKey;
        when(() => testContext.mockUuid.v4()).thenReturn('stream-round-trip');
        when(() => testContext.mockSecureFilesBox.put(any<String>(), any<Object?>())).thenAnswer((
          invocation,
        ) async {
          storedChunks[firstPositionalName(invocation)] = invocation.positionalArguments[1];
        });
        when(
          () => testContext.mockSecureFilesBox.get(any<String>()),
        ).thenAnswer((invocation) async => storedChunks[invocation.positionalArguments[0]]);
        when(
          () => testContext.mockSecureStorage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          ),
        ).thenAnswer((invocation) async {
          encodedKey = namedStringValue(invocation);
        });
        when(
          () => testContext.mockSecureStorage.read(key: any(named: 'key')),
        ).thenAnswer((_) async => encodedKey);

        final original = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7]);
        final metadata = await fileOperations.saveSecureFileStream(
          SecureFileStreamRequest(
            stream: .value(original),
            fileExtension: 'bin',
            services: testContext.fileServices(isWeb: true),
            chunkSize: 3,
          ),
        );

        expect(metadata, isNot(contains('nonce')));
        expect(
          await fileOperations.getSecureFile(
            fileMetadata: metadata,
            isWeb: true,
            secureStorage: testContext.mockSecureStorage,
            getBox: testContext.getBox,
          ),
          original,
        );
      });

      group('streamed web chunks', () {
        late Map<String, dynamic> storedChunks;
        late Map<String, dynamic> metadata;
        final original = Uint8List.fromList(.generate(10, (index) => index + 1));

        setUp(() async {
          storedChunks = {};
          String? encodedKey;
          when(() => testContext.mockUuid.v4()).thenReturn('ordered-chunks');
          when(() => testContext.mockSecureFilesBox.put(any<String>(), any<Object?>())).thenAnswer((
            invocation,
          ) async {
            storedChunks[firstPositionalName(invocation)] = invocation.positionalArguments[1];
          });
          when(
            () => testContext.mockSecureStorage.write(
              key: any(named: 'key'),
              value: any(named: 'value'),
            ),
          ).thenAnswer((invocation) async {
            encodedKey = namedStringValue(invocation);
          });
          when(
            () => testContext.mockSecureStorage.read(key: any(named: 'key')),
          ).thenAnswer((_) async => encodedKey);
          metadata = await fileOperations.saveSecureFileStream(
            SecureFileStreamRequest(
              stream: .value(original),
              fileExtension: 'bin',
              services: testContext.fileServices(isWeb: true),
              chunkSize: 2,
            ),
          );
        });

        test('joins chunks in index order when earlier chunks load last', () async {
          expect(metadata['chunkCount'], 5);
          when(() => testContext.mockSecureFilesBox.get(any<String>())).thenAnswer((
            invocation,
          ) async {
            final name = firstPositionalName(invocation);
            final index = int.parse(name.split(':c:').last);
            await Future<void>.delayed(Duration(milliseconds: (5 - index) * 5));
            return storedChunks[name];
          });

          expect(
            await fileOperations.getSecureFile(
              fileMetadata: metadata,
              isWeb: true,
              secureStorage: testContext.mockSecureStorage,
              getBox: testContext.getBox,
            ),
            original,
          );
        });

        test('names the missing chunk when one chunk is not stored', () async {
          when(() => testContext.mockSecureFilesBox.get(any<String>())).thenAnswer((
            invocation,
          ) async {
            final name = firstPositionalName(invocation);
            return name.endsWith(':c:3') ? null : storedChunks[name];
          });

          await expectLater(
            fileOperations.getSecureFile(
              fileMetadata: metadata,
              isWeb: true,
              secureStorage: testContext.mockSecureStorage,
              getBox: testContext.getBox,
            ),
            throwsA(
              isA<FileNotFoundError>().having(
                (e) => e.toString(),
                'message',
                contains('Hive secure files chunk 3'),
              ),
            ),
          );
        });
      });

      test('should retrieve secure file successfully on native platforms', () async {
        // Arrange
        const testFileId = 'test-file-id';
        const secureKeyName = 'file_key_$testFileId';
        final testKey = Uint8List.fromList(.generate(32, (i) => i));

        final fileMetadata = {
          'fileId': testFileId,
          'filePath': '/test/path/$testFileId.txt.enc',
          'secureKeyName': secureKeyName,
          'nonce': 'dGVzdE5vbmNl', // base64 encoded test nonce
          'mac': 'dGVzdE1hYw==', // base64 encoded test MAC
          'extension': 'txt',
        };

        when(
          () => testContext.mockSecureStorage.read(key: secureKeyName),
        ).thenAnswer((_) async => base64Encode(testKey));

        expect(
          () => fileOperations.getSecureFile(
            fileMetadata: fileMetadata,
            isWeb: false,
            secureStorage: testContext.mockSecureStorage,
            getBox: testContext.getBox,
          ),
          throwsA(isA<VaultStorageReadError>()),
        );
      });

      test('should retrieve secure file successfully on web platform', () async {
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

        when(
          () => mockBox.get(testFileId),
        ).thenAnswer((_) async => 'dGVzdENvbnRlbnQ='); // base64 encoded test content
        when(
          () => testContext.mockSecureStorage.read(key: secureKeyName),
        ).thenAnswer((_) async => 'dGVzdEtleQ=='); // base64 encoded test key

        expect(
          () => fileOperations.getSecureFile(
            fileMetadata: fileMetadata,
            isWeb: true,
            secureStorage: testContext.mockSecureStorage,
            getBox: testContext.getBox,
          ),
          throwsA(isA<VaultStorageReadError>()),
        );
      });

      test('should throw FileNotFoundError when file does not exist on web', () async {
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

      test('should throw KeyNotFoundError when encryption key is missing', () async {
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

        when(() => mockBox.get(testFileId)).thenAnswer((_) async => 'dGVzdENvbnRlbnQ=');
        when(
          () => testContext.mockSecureStorage.read(key: secureKeyName),
        ).thenAnswer((_) async => null);

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

      test('should throw InvalidMetadataError when required fields are missing', () async {
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
      test('should delete secure file successfully on native platforms', () async {
        // Arrange
        const testFileId = 'test-file-id';
        const secureKeyName = 'file_key_$testFileId';

        final fileMetadata = {
          'fileId': testFileId,
          'filePath': '/test/path/$testFileId.txt.enc',
          'secureKeyName': secureKeyName,
        };

        when(
          () => testContext.mockSecureStorage.delete(key: secureKeyName),
        ).thenAnswer((_) async {});

        // Act
        await fileOperations.deleteSecureFile(
          fileMetadata: fileMetadata,
          isWeb: false,
          secureStorage: testContext.mockSecureStorage,
          getBox: testContext.getBox,
        );

        // Assert
        verify(() => testContext.mockSecureStorage.delete(key: secureKeyName)).called(1);
      });

      test('should delete secure file successfully on web platform', () async {
        // Arrange
        const testFileId = 'test-file-id';
        const secureKeyName = 'file_key_$testFileId';
        final mockBox = testContext.mockSecureFilesBox;

        final fileMetadata = {'fileId': testFileId, 'secureKeyName': secureKeyName};

        when(() => mockBox.delete(testFileId)).thenAnswer((_) async {});
        when(
          () => testContext.mockSecureStorage.delete(key: secureKeyName),
        ).thenAnswer((_) async {});

        // Act
        await fileOperations.deleteSecureFile(
          fileMetadata: fileMetadata,
          isWeb: true,
          secureStorage: testContext.mockSecureStorage,
          getBox: testContext.getBox,
        );

        // Assert
        verify(() => mockBox.delete(testFileId)).called(1);
        verify(() => testContext.mockSecureStorage.delete(key: secureKeyName)).called(1);
      });

      test('should throw VaultStorageDeleteError when deletion fails', () async {
        // Arrange
        const testFileId = 'test-file-id';
        const secureKeyName = 'file_key_$testFileId';

        final fileMetadata = {'fileId': testFileId, 'secureKeyName': secureKeyName};

        when(
          () => testContext.mockSecureStorage.delete(key: secureKeyName),
        ).thenThrow(Exception('Deletion failed'));

        // Act & Assert
        expect(
          () => fileOperations.deleteSecureFile(
            fileMetadata: fileMetadata,
            isWeb: true,
            secureStorage: testContext.mockSecureStorage,
            getBox: testContext.getBox,
          ),
          throwsA(isA<VaultStorageDeleteError>()),
        );
      });
    });
  });
}
